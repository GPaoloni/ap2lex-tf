resource "twilio_autopilot_assistants_v1" "development_pre_survey" {
  unique_name   = "demo_chatbot"
  friendly_name = "A bot that collects a pre-survey"
  style_sheet = jsonencode({
    "style_sheet" : {
      "collect" : {
        "validate" : {
          "on_failure" : {
            "repeat_question" : false,
            "messages" : [
              {
                "say" : {
                  "speech" : "I didn't get that. What did you say?"
                }
              },
              {
                "say" : {
                  "speech" : "I still didn't catch that. Please repeat."
                }
              },
              {
                "say" : {
                  "speech" : "Let's try one last time. Say it again please."
                }
              }
            ]
          },
          "on_success" : {
            "say" : {
              "speech" : ""
            }
          },
          "max_attempts" : 4
        }
      },
      "voice" : {
        "say_voice" : "Polly.Matthew"
      },
      "name" : ""
    }
  })
  defaults = jsonencode({
    "defaults" : {
      "assistant_initiation" : "task://greeting",
      "fallback" : "task://fallback",
      "collect" : {
        "validate_on_failure" : "task://collect_fallback"
      }
    }
  })
  log_queries = true
}

resource "twilio_autopilot_assistants_tasks_v1" "development_pre_survey_redirect_function" {
  unique_name   = "redirect_function"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  actions = jsonencode({
    "actions" : [
      {
        "redirect" : {
          "method" : "POST",
          "uri" : "https://serverless-9971-production.twil.io/autopilotRedirect"
        }
      }
    ]
  })
}

resource "twilio_autopilot_assistants_tasks_v1" "development_pre_survey_survey" {
  unique_name   = "survey"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  actions = jsonencode({
    "actions" : [
      {
        "remember" : {
          "at" : "survey"
        }
      },
      {
        "say" : "Thank you. You can say 'prefer not to answer' (or type X) to any question."
      },
      {
        "collect" : {
          "on_complete" : {
            "redirect" : "task://redirect_function"
          },
          "name" : "collect_survey",
          "questions" : [
            {
              "type" : "Age",
              "validate" : {
                "on_failure" : {
                  "repeat_question" : true,
                  "messages" : [
                    {
                      "say" : "Sorry, I didn't understand that. Please respond with a number."
                    },
                    {
                      "say" : "Sorry, I still didn't get that."
                    }
                  ]
                },
                "max_attempts" : {
                  "redirect" : "task://redirect_function",
                  "num_attempts" : 2
                }
              },
              "question" : "How old are you?",
              "name" : "age"
            },
            {
              "type" : "Gender",
              "validate" : {
                "on_failure" : {
                  "repeat_question" : true,
                  "messages" : [
                    {
                      "say" : "Sorry, I didn't understand that. Please try again."
                    },
                    {
                      "say" : "Sorry, I still didn't get that."
                    }
                  ]
                },
                "max_attempts" : {
                  "redirect" : "task://redirect_function",
                  "num_attempts" : 2
                }
              },
              "question" : "What is your gender?",
              "name" : "gender"
            }
          ]
        }
      }
    ]
  })
}

resource "twilio_autopilot_assistants_tasks_v1" "development_pre_survey_gender_why" {
  unique_name   = "gender_why"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  actions = jsonencode({
    "actions" : [
      {
        "remember" : {
          "at" : "gender_why"
        }
      },
      {
        "collect" : {
          "on_complete" : {
            "redirect" : "task://redirect_function"
          },
          "name" : "collect_survey",
          "questions" : [
            {
              "type" : "Gender",
              "validate" : {
                "on_failure" : {
                  "messages" : [
                    {
                      "say" : "Got it."
                    }
                  ]
                },
                "max_attempts" : {
                  "redirect" : "task://redirect_function",
                  "num_attempts" : 1
                },
                "allowed_values" : {
                  "list" : [
                    "Boy",
                    "Girl",
                    "Non-binary"
                  ]
                }
              },
              "question" : "We ask for gender--whether you identify as a boy, girl, or neither--to help understand who is using our helpline. If you're uncomfortable answering, just say 'prefer not to answer.'",
              "name" : "gender"
            }
          ]
        }
      }
    ]
  })
}

resource "twilio_autopilot_assistants_tasks_v1" "development_pre_survey_survey_start" {
  unique_name   = "survey_start"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  actions = jsonencode({
    "actions" : [
      {
        "remember" : {
          "at" : "survey_start"
        }
      },
      {
        "collect" : {
          "on_complete" : {
            "redirect" : "task://survey"
          },
          "name" : "collect_survey",
          "questions" : [
            {
              "type" : "Twilio.YES_NO",
              "validate" : {
                "on_failure" : {
                  "repeat_question" : true,
                  "messages" : [
                    {
                      "say" : "Sorry, I didn't understand that."
                    },
                    {
                      "say" : "I still didn't get that."
                    }
                  ]
                },
                "max_attempts" : {
                  "redirect" : "task://redirect_function",
                  "num_attempts" : 2
                }
              },
              "question" : "Are you calling about yourself? Please answer Yes or No.",
              "name" : "about_self"
            }
          ]
        }
      }
    ]
  })
}

resource "twilio_autopilot_assistants_tasks_v1" "development_pre_survey_counselor_handoff" {
  unique_name   = "counselor_handoff"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  actions = jsonencode({
    "actions" : [
      {
        "remember" : {
          "sendToAgent" : true,
          "at" : "counselor_handoff"
        }
      },
      {
        "say" : "We'll transfer you now. Please hold for a counsellor."
      }
    ]
  })
}

resource "twilio_autopilot_assistants_tasks_v1" "development_pre_survey_greeting" {
  unique_name   = "greeting"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  actions = jsonencode({
    "actions" : [
      {
        "remember" : {
          "at" : "greeting"
        }
      },
      {
        "say" : "Welcome to the helpline. To help us better serve you, please answer the following three questions."
      },
      {
        "redirect" : "task://survey_start"
      }
    ]
  })
}

resource "twilio_autopilot_assistants_tasks_samples_v1" "development_pre_survey_greeting_group" {
  for_each      = toset(["yo", "sup", "whatsup", "what can you do", "what do you do", "what'us up", "hello", "hi there.", "hey", "Hello.", "Hi", "heya", "good morning", "good afternoon", "hi there", "hi!"])
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  task_sid      = twilio_autopilot_assistants_tasks_v1.development_pre_survey_greeting.sid
  language      = "en-US"
  tagged_text   = each.key
}

resource "twilio_autopilot_assistants_tasks_v1" "development_pre_survey_collect_fallback" {
  unique_name   = "collect_fallback"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  actions = jsonencode({
    "actions" : [
      {
        "say" : "Looks like I'm having trouble. Apologies for that. Let's start again, how can I help you today?"
      },
      {
        "listen" : true
      }
    ]
  })
}

resource "twilio_autopilot_assistants_tasks_v1" "development_pre_survey_fallback" {
  unique_name   = "fallback"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  actions = jsonencode({
    "actions" : [
      {
        "say" : "I'm sorry didn't quite get that. Please try that again."
      },
      {
        "listen" : true
      }
    ]
  })
}

resource "twilio_autopilot_assistants_tasks_v1" "development_pre_survey_goodbye" {
  unique_name   = "goodbye"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  actions = jsonencode({
    "actions" : [
      {
        "say" : "Thank you! Please reach out again if you need anything. Goodbye."
      }
    ]
  })
}

resource "twilio_autopilot_assistants_tasks_samples_v1" "development_pre_survey_goodbye_group" {
  for_each      = toset(["that's all", "bye bye", "see ya", "stop", "stop talking", "good bye", "cancel", "goodnight", "goodbye", "that would be all", "no thanks", "no", "that would be all thanks", "go away", "that's all for today", "that is all thank you", "no thanks"])
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
  task_sid      = twilio_autopilot_assistants_tasks_v1.development_pre_survey_goodbye.sid
  language      = "en-US"
  tagged_text   = each.key
}

resource "twilio_autopilot_assistants_field_types_v1" "development_pre_survey_Age" {
  unique_name   = "Age"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
}

resource "twilio_autopilot_assistants_field_types_field_values_v1" "development_pre_survey_values_Age_group" {
  for_each       = toset(["100", "99", "98", "97", "96", "95", "94", "93", "92", "91", "90", "89", "88", "87", "86", "85", "84", "83", "82", "81", "80", "79", "78", "77", "76", "75", "74", "73", "72", "71", "70", "69", "68", "67", "66", "65", "64", "63", "62", "61", "60", "59", "58", "57", "56", "55", "54", "53", "52", "51", "50", "49", "48", "47", "46", "45", "44", "43", "42", "41", "40", "39", "38", "37", "36", "35", "34", "33", "32", "31", "30", "29", "28", "27", "26", "25", "24", "23", "22", "21", "20", "19", "18", "17", "16", "15", "14", "13", "12", "11", "10", "9", "8", "7", "6", "5", "4", "Unknown", "3", "2", "1"])
  assistant_sid  = twilio_autopilot_assistants_v1.development_pre_survey.sid
  field_type_sid = twilio_autopilot_assistants_field_types_v1.development_pre_survey_Age.sid
  value          = each.key
  language       = "en-US"
}

resource "twilio_autopilot_assistants_field_types_field_values_v1" "development_pre_survey_synonymsOf_Unknown_Age_group" {
  depends_on     = [twilio_autopilot_assistants_field_types_field_values_v1.development_pre_survey_values_Age_group]
  for_each       = toset(["prefer not to", "prefer not", "X", "Prefer not to answer"])
  assistant_sid  = twilio_autopilot_assistants_v1.development_pre_survey.sid
  field_type_sid = twilio_autopilot_assistants_field_types_v1.development_pre_survey_Age.sid
  synonym_of     = "Unknown"
  value          = each.key
  language       = "en-US"
}

resource "twilio_autopilot_assistants_field_types_v1" "development_pre_survey_Gender" {
  unique_name   = "Gender"
  assistant_sid = twilio_autopilot_assistants_v1.development_pre_survey.sid
}

resource "twilio_autopilot_assistants_field_types_field_values_v1" "development_pre_survey_values_Gender_group" {
  for_each       = toset(["Non-Binary", "Unknown", "Girl", "Boy"])
  assistant_sid  = twilio_autopilot_assistants_v1.development_pre_survey.sid
  field_type_sid = twilio_autopilot_assistants_field_types_v1.development_pre_survey_Gender.sid
  value          = each.key
  language       = "en-US"
}

resource "twilio_autopilot_assistants_field_types_field_values_v1" "development_pre_survey_synonymsOf_Non-Binary_Gender_group" {
  depends_on     = [twilio_autopilot_assistants_field_types_field_values_v1.development_pre_survey_values_Gender_group]
  for_each       = toset(["non binary", "agender", "nonbinary", "NB"])
  assistant_sid  = twilio_autopilot_assistants_v1.development_pre_survey.sid
  field_type_sid = twilio_autopilot_assistants_field_types_v1.development_pre_survey_Gender.sid
  synonym_of     = "Non-Binary"
  value          = each.key
  language       = "en-US"
}

resource "twilio_autopilot_assistants_field_types_field_values_v1" "development_pre_survey_synonymsOf_Boy_Gender_group" {
  depends_on     = [twilio_autopilot_assistants_field_types_field_values_v1.development_pre_survey_values_Gender_group]
  for_each       = toset(["B", "males", "dude", "guy", "M", "man", "male"])
  assistant_sid  = twilio_autopilot_assistants_v1.development_pre_survey.sid
  field_type_sid = twilio_autopilot_assistants_field_types_v1.development_pre_survey_Gender.sid
  synonym_of     = "Boy"
  value          = each.key
  language       = "en-US"
}

resource "twilio_autopilot_assistants_field_types_field_values_v1" "development_pre_survey_synonymsOf_Girl_Gender_group" {
  depends_on     = [twilio_autopilot_assistants_field_types_field_values_v1.development_pre_survey_values_Gender_group]
  for_each       = toset(["G", "females", "lady", "female", "F", "W", "woman"])
  assistant_sid  = twilio_autopilot_assistants_v1.development_pre_survey.sid
  field_type_sid = twilio_autopilot_assistants_field_types_v1.development_pre_survey_Gender.sid
  synonym_of     = "Girl"
  value          = each.key
  language       = "en-US"
}

resource "twilio_autopilot_assistants_field_types_field_values_v1" "development_pre_survey_synonymsOf_Unknown_Gender_group" {
  depends_on     = [twilio_autopilot_assistants_field_types_field_values_v1.development_pre_survey_values_Gender_group]
  for_each       = toset(["prefer not to", "prefer not", "none of your business", "X", "prefer not to answer"])
  assistant_sid  = twilio_autopilot_assistants_v1.development_pre_survey.sid
  field_type_sid = twilio_autopilot_assistants_field_types_v1.development_pre_survey_Gender.sid
  synonym_of     = "Unknown"
  value          = each.key
  language       = "en-US"
}