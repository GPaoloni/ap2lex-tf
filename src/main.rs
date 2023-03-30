use std::fs;

mod ast;
mod json_utils;
mod parser;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let autopilot_source = fs::read_to_string("./development_pre_survey.tf")?;

    match parser::parse_resources(&autopilot_source) {
        Ok((rest, parsed_resources)) => {
            println!("The rest is {:#?}", rest);
            println!("The parsed resources are {:#?}", parsed_resources);
            parsed_resources.iter().for_each(|r| println!("{}", r.res_name));
            println!("The count of parsed resources is {}", parsed_resources.len());
        }
        Err(err) => println!("Parsing went wrong: {}", err),
    }

    Ok(())
}
