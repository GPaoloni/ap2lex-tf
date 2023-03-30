use crate::json_utils::JsonValue;

#[derive(Debug, PartialEq)]
pub enum ResourcePropertyValue {
    VNull,
    VBoolean(bool),
    VString(String),
    VJson(JsonValue),
    VSet(Vec<String>),
    VEach,
    VReference { res_type: String, res_name: String },
}

pub type ResourceProperty = (String, ResourcePropertyValue);

pub type ResourceDefinition = Vec<ResourceProperty>;

#[derive(Debug, PartialEq)]
pub struct Resource {
    pub res_type: String,
    pub res_def: ResourceDefinition,
    pub res_name: String,
}
