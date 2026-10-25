# {"text": "quote\" back\\ nl\n tab\t ctl\u0001 é /", "empty": [], "none": {},
#  "numbers": [1, 2.5], "nested": {"k": null, "list": ["a", "b"]}}
def json_sample(json)
  json.begin_object
  json.key("text")
  json.string("quote\" back\\ nl\n tab\t ctl\u0001 é /")
  json.key("empty")
  json.begin_array
  json.end_array
  json.key("none")
  json.begin_object
  json.end_object
  json.key("numbers")
  json.begin_array
  json.literal("1")
  json.literal("2.5")
  json.end_array
  json.key("nested")
  json.begin_object
  json.key("k")
  json.string(nil)
  json.key("list")
  json.begin_array
  json.string("a")
  json.string("b")
  json.end_array
  json.end_object
  json.end_object
  json.output
end
