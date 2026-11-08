///|
test "processors normalize multilingual whitespace" {
  let p : @core.Page = {
    url: "https://a.com/",
    title: "",
    description: "",
    text: "  hello\n\t世界  ",
    links: [],
    images: [],
    canonical: "",
    metadata: {},
  }
  let processors : Array[&@pipeline.Processor] = [@pipeline.CleanText::{ }]
  assert_eq(@pipeline.run(p, processors).unwrap().text, "hello 世界")
}
