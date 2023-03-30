use crate::{
    ast::{Resource, ResourceDefinition, ResourceProperty, ResourcePropertyValue},
    json_utils,
};
use nom::{
    branch::alt,
    bytes::complete::{is_not, tag, take_until, take_while},
    character::complete::{char, multispace0},
    combinator::{cut, map, value},
    error::{Error, ParseError},
    multi::{many0, separated_list0, separated_list1},
    sequence::{delimited, preceded, separated_pair, terminated, tuple},
    IResult,
};

/// A combinator that takes a parser `inner` and produces a parser that also consumes both leading and
/// trailing whitespace, returning the output of `inner`.
fn ws<'a, F, O, E: ParseError<&'a str>>(inner: F) -> impl FnMut(&'a str) -> IResult<&'a str, O, E>
where
    F: FnMut(&'a str) -> IResult<&'a str, O, E>,
{
    delimited(multispace0, inner, multispace0)
}

fn parse_resource_identifier(i: &str) -> IResult<&str, &str> {
    ws(preceded(
        char('\"'),
        cut(terminated(take_while(|c| c != '"'), char('\"'))),
    ))(i)
}

fn parse_resource_property_key(i: &str) -> IResult<&str, String> {
    map(ws(take_while(|c| !(c == ' ' || c == '='))), |s| {
        s.to_string()
    })(i)
}

// Parsers used for the value of a single resource property
//

fn parse_vnull(i: &str) -> IResult<&str, ()> {
    ws(value((), tag("null")))(i)
}

fn parse_vbool(i: &str) -> IResult<&str, bool> {
    let parse_true = value(true, tag("true"));
    let parse_false = value(false, tag("false"));

    ws(alt((parse_true, parse_false)))(i)
}

fn parse_string(i: &str) -> IResult<&str, String> {
    let (i, s) = ws(delimited(char('\"'), is_not("\""), char('\"')))(i)?;

    Ok((i, s.to_string()))
}

fn parse_vstring(i: &str) -> IResult<&str, String> {
    parse_string(i)
}

fn parse_vjson(i: &str) -> IResult<&str, json_utils::JsonValue> {
    ws(preceded(
        tag("jsonencode("),
        terminated(json_utils::root, char(')')),
    ))(i)
}

// Only parses an array of strings for now
fn parse_array(i: &str) -> IResult<&str, Vec<String>> {
    delimited(
        ws(char('[')),
        separated_list0(ws(char(',')), parse_string),
        ws(char(']')),
    )(i)
}

fn parse_vset(i: &str) -> IResult<&str, Vec<String>> {
    ws(preceded(
        tag("toset("),
        cut(terminated(
            parse_array,
            // This would change return signature to Vec<JsonValue>, but I'm not sure if tf sets are json valid format, we'll find out :)
            // json_utils::array,
            char(')'),
        )),
    ))(i)
}

// Only parses usage of .key for now
fn parse_veach(i: &str) -> IResult<&str, &str> {
    ws(tag("each.key"))(i)
}

fn parse_vreference(i: &str) -> IResult<&str, (String, String)> {
    let no_dot_or_whitespace = |c: char| c != '.' && !c.is_ascii_whitespace();

    map(
        ws(tuple((
            separated_pair(
                take_while(no_dot_or_whitespace),
                char('.'),
                take_while(no_dot_or_whitespace),
            ),
            take_while(|c: char| !c.is_ascii_whitespace()),
        ))),
        |((res_type, res_name), _rest)| (res_type.to_string(), res_name.to_string()),
    )(i)
}

fn parse_resource_property_value(i: &str) -> IResult<&str, ResourcePropertyValue> {
    alt((
        map(parse_vjson, ResourcePropertyValue::VJson),
        map(parse_vset, ResourcePropertyValue::VSet),
        map(parse_vstring, ResourcePropertyValue::VString),
        map(parse_vreference, |(res_type, res_name)| {
            ResourcePropertyValue::VReference { res_type, res_name }
        }),
        map(parse_veach, |_| ResourcePropertyValue::VEach),
        map(parse_vbool, ResourcePropertyValue::VBoolean),
        map(parse_vnull, |_| ResourcePropertyValue::VNull),
    ))(i)
}

fn parse_resource_definition_property(i: &str) -> IResult<&str, ResourceProperty> {
    let (i, (key, _, value)) = tuple((
        parse_resource_property_key,
        ws(char('=')),
        parse_resource_property_value,
    ))(i)?;

    Ok((i, (key, value)))
}

fn parse_resource_definition(i: &str) -> IResult<&str, ResourceDefinition> {
    let (i, _) = ws(char('{'))(i)?;

    let (i, definition_properties) = many0(parse_resource_definition_property)(i)?;

    let (i, _) = ws(char('}'))(i)?;

    Ok((i, definition_properties))
}

fn parse_resource(i: &str) -> IResult<&str, Resource> {
    let (i, (_, res_type, res_name, res_def)) = ws(tuple((
        tag("resource"),
        parse_resource_identifier,
        parse_resource_identifier,
        parse_resource_definition,
    )))(i)?;

    Ok((
        i,
        Resource {
            res_type: res_type.to_string(),
            res_def,
            res_name: res_name.to_string(),
        },
    ))
}

pub fn parse_resources(i: &str) -> IResult<&str, Vec<Resource>> {
    let (i, _o) = take_until("resource")(i)?;

    let (i, o) = many0(parse_resource)(i)?;

    Ok((i, o))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::json_utils::JsonValue;
    use std::collections::HashMap;

    #[test]
    fn parse_resource_identifier_success() {
        let result = parse_resource_identifier("\"resource_identifier\"").unwrap();
        assert_eq!(result, ("", "resource_identifier"));
    }

    #[test]
    fn parse_resource_simple() {
        let ap_resource = "resource \"res_type\" \"res_name\" {
            unique_name       = \"some_unique_name\"
            another_property     = \"Another property that contains spaces and =\"
        }";

        let expected = Resource {
            res_type: "res_type".to_string(),
            res_name: "res_name".to_string(),
            res_def: vec![
                (
                    "unique_name".to_string(),
                    ResourcePropertyValue::VString("some_unique_name".to_owned()),
                ),
                (
                    "another_property".to_string(),
                    ResourcePropertyValue::VString(
                        "Another property that contains spaces and =".to_owned(),
                    ),
                ),
            ],
        };

        let result = parse_resources(ap_resource).expect("Failed parsing the data");

        assert_eq!(result, ("", vec![expected]));
    }

    #[test]
    fn parse_resource_json() {
        let ap_resource = "resource \"res_type\" \"res_name\" {
            unique_name       = \"some_unique_name\"
            json_property     = jsonencode({
                \"array\": [1,2,3],
                \"object\": {\"a\": \"a\"},
                \"string\": \"Just a string with spaces\",
                \"boolean\": true
            })
        }";

        let expected = Resource {
            res_type: "res_type".to_string(),
            res_name: "res_name".to_string(),
            res_def: vec![
                (
                    "unique_name".to_string(),
                    ResourcePropertyValue::VString("some_unique_name".to_owned()),
                ),
                (
                    "json_property".to_string(),
                    ResourcePropertyValue::VJson(JsonValue::Object(HashMap::from([
                        (
                            "string".to_string(),
                            JsonValue::Str("Just a string with spaces".to_string()),
                        ),
                        ("boolean".to_string(), JsonValue::Boolean(true)),
                        (
                            "array".to_string(),
                            JsonValue::Array(vec![
                                JsonValue::Num(1.0),
                                JsonValue::Num(2.0),
                                JsonValue::Num(3.0),
                            ]),
                        ),
                        (
                            "object".to_string(),
                            JsonValue::Object(HashMap::from([(
                                "a".to_string(),
                                JsonValue::Str("a".to_string()),
                            )])),
                        ),
                    ]))),
                ),
            ],
        };

        let result = parse_resources(ap_resource).expect("Failed parsing the data");

        assert_eq!(result, ("", vec![expected]));
    }

    #[test]
    fn parse_resource_set() {
        let ap_resource = "resource \"res_type\" \"res_name\" {
            unique_name       = \"some_unique_name\"
            set_property     = toset([\"a\", \"b\"])
        }";

        let expected = Resource {
            res_type: "res_type".to_string(),
            res_name: "res_name".to_string(),
            res_def: vec![
                (
                    "unique_name".to_string(),
                    ResourcePropertyValue::VString("some_unique_name".to_owned()),
                ),
                (
                    "set_property".to_string(),
                    ResourcePropertyValue::VSet(vec!["a".to_string(), "b".to_string()]),
                ),
            ],
        };

        let result = parse_resources(ap_resource).expect("Failed parsing the data");

        assert_eq!(result, ("", vec![expected]));
    }

    #[test]
    fn parse_resource_reference() {
        let ap_resource = "resource \"res_type\" \"res_name\" {
            unique_name       = \"some_unique_name\"
            reference_property     = parent_ref_type.parent_ref_name.other
        }";

        let expected = Resource {
            res_type: "res_type".to_string(),
            res_name: "res_name".to_string(),
            res_def: vec![
                (
                    "unique_name".to_string(),
                    ResourcePropertyValue::VString("some_unique_name".to_owned()),
                ),
                (
                    "reference_property".to_string(),
                    ResourcePropertyValue::VReference {
                        res_type: "parent_ref_type".to_string(),
                        res_name: "parent_ref_name".to_string(),
                    },
                ),
            ],
        };

        let result = parse_resources(ap_resource).expect("Failed parsing the data");

        assert_eq!(result, ("", vec![expected]));
    }

    #[test]
    fn parse_resource_null() {
        let ap_resource = "resource \"res_type\" \"res_name\" {
            unique_name       = \"some_unique_name\"
            null_property     = null
        }";

        let expected = Resource {
            res_type: "res_type".to_string(),
            res_name: "res_name".to_string(),
            res_def: vec![
                (
                    "unique_name".to_string(),
                    ResourcePropertyValue::VString("some_unique_name".to_owned()),
                ),
                ("null_property".to_string(), ResourcePropertyValue::VNull),
            ],
        };

        let result = parse_resources(ap_resource).expect("Failed parsing the data");

        assert_eq!(result, ("", vec![expected]));
    }

    #[test]
    fn parse_resource_bool() {
        let ap_resource = "resource \"res_type\" \"res_name\" {
            unique_name       = \"some_unique_name\"
            true_property     = true
            false_property     = false
        }";

        let expected = Resource {
            res_type: "res_type".to_string(),
            res_name: "res_name".to_string(),
            res_def: vec![
                (
                    "unique_name".to_string(),
                    ResourcePropertyValue::VString("some_unique_name".to_owned()),
                ),
                (
                    "true_property".to_string(),
                    ResourcePropertyValue::VBoolean(true),
                ),
                (
                    "false_property".to_string(),
                    ResourcePropertyValue::VBoolean(false),
                ),
            ],
        };

        let result = parse_resources(ap_resource).expect("Failed parsing the data");

        assert_eq!(result, ("", vec![expected]));
    }

    #[test]
    fn parse_test() {
        let ap_resource = "resource \"twilio_autopilot_assistants_tasks_v1\" \"development_pre_survey_redirect_function\" {
            unique_name   = \"redirect_function\"
            assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
            actions = jsonencode({
              \"actions\" : [
                {
                  \"redirect\" : {
                    \"method\" : \"POST\",
                    \"uri\" : \"https://serverless-9971-production.twil.io/autopilotRedirect\"
                  }
                }
              ]
            })
          }";

        let result = parse_resources(ap_resource).expect("Failed parsing the data");

        println!("{:#?}", result);
    }
}
