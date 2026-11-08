///|
fn usage() -> Unit {
  println(
    "MoonCrawler 0.2\n  init CONFIG.json\n  validate CONFIG.json\n  crawl CONFIG.json JOBDIR SEED [SEED ...]\n  resume JOBDIR\n  pause JOBDIR\n  status JOBDIR\n  stats JOBDIR\n  export JOBDIR OUTPUT.jsonl",
  )
}

///|
async fn config_file(path : String) -> @core.Config {
  let config : @core.Config = @core.decode_config(
    @json.parse(@storage.read_text(path), reject_duplicate_keys=true),
  )
  config.validate()
  config
}

///|
async fn saved_job(directory : String) -> @storage.Snapshot {
  guard @storage.read_snapshot(directory) is Some(saved) else {
    raise @core.Storage("no checkpoint in job directory")
  }
  saved
}

///|
async fn crawl(
  config : @core.Config?,
  directory : String,
  seeds : Array[String],
  resume_job : Bool,
) -> Unit {
  let store = @storage.FileStore::open(directory)
  defer store.close()
  let adapter : &@storage.Storage = store
  let saved = adapter.load()
  let config = config.unwrap_or_else(() => saved.unwrap().config)
  if !resume_job && saved is Some(_) {
    raise @core.Invalid("job already exists; use resume or another directory")
  }
  let program = @env.get_env_var("MOONCRAWLER_CURL").unwrap_or("curl")
  let fetcher : @fetcher.CurlFetcher = { program, }
  let engine = @engine.Engine::new(config, fetcher, store, snapshot?=saved)
  for seed in seeds {
    if !engine.seed(seed) {
      println("seed skipped by dedup/depth/filter/capacity")
    }
  }
  if @fs.exists(directory + "/pause") {
    @fs.remove(directory + "/pause")
  }
  engine.run(should_stop=() => @fs.exists(directory + "/pause"))
  println(
    "saved \{engine.pages().length()} pages; succeeded=\{engine.frontier.count(Succeeded)} failed=\{engine.frontier.count(PermanentlyFailed)} pending=\{engine.frontier.count(Pending) + engine.frontier.count(RetryPending)}",
  )
}

///|
async fn dispatch(args : Array[String]) -> Unit {
  guard args.length() >= 2 else {
    usage()
    return
  }
  match args[1] {
    "init" => {
      guard args.length() == 3 else {
        raise @core.Invalid("init requires CONFIG.json")
      }
      @fs.write_file(
        args[2],
        @json.to_json(@core.Config::default()).stringify(indent=2) + "\n",
        create_mode=CreateNew,
      )
      println("configuration created")
    }
    "validate" => {
      guard args.length() == 3 else {
        raise @core.Invalid("validate requires CONFIG.json")
      }
      ignore(config_file(args[2]))
      println("configuration valid")
    }
    "crawl" => {
      guard args.length() >= 5 else {
        raise @core.Invalid("crawl requires CONFIG.json JOBDIR SEED [SEED ...]")
      }
      crawl(Some(config_file(args[2])), args[3], args[4:].to_owned(), false)
    }
    "resume" => {
      guard args.length() == 3 else {
        raise @core.Invalid("resume requires JOBDIR")
      }
      crawl(None, args[2], [], true)
    }
    "pause" => {
      guard args.length() == 3 else {
        raise @core.Invalid("pause requires JOBDIR")
      }
      ignore(saved_job(args[2]))
      @fs.write_file(args[2] + "/pause", "pause\n")
      println("pause requested; in-flight tasks will drain")
    }
    "status" | "stats" => {
      guard args.length() == 3 else {
        raise @core.Invalid("status/stats requires JOBDIR")
      }
      let saved = saved_job(args[2])
      let counts : Map[String, Int32] = Map([])
      for task in saved.tasks {
        let state = @json.to_json(task.state).stringify()
        counts[state] = counts.get(state).unwrap_or(0) + 1
      }
      let output : Map[String, Json] = {
        "version": @json.to_json(saved.version),
        "saved_at": @json.to_json(saved.saved_at),
        "pages": @json.to_json(saved.pages.length()),
        "tasks": @json.to_json(counts),
      }
      if args[1] == "stats" {
        let mut attempts = 0
        let mut retries = 0
        for task in saved.tasks {
          attempts += task.attempts
          retries += (task.attempts - 1).max(0)
        }
        output["task_attempts"] = @json.to_json(attempts)
        output["task_retries"] = @json.to_json(retries)
      } else {
        output["errors"] = @json.to_json(
          saved.tasks
          .filter(t => !t.error.is_empty())
          .map(t => { "url": t.request.url.key(), "reason": t.error }),
        )
      }
      println(@json.to_json(output).stringify(indent=2))
    }
    "export" => {
      guard args.length() == 4 else {
        raise @core.Invalid("export requires JOBDIR OUTPUT.jsonl")
      }
      // Refuse overwrite, including accidental overwrite of the active checkpoint.
      @fs.write_file(
        args[3],
        @storage.jsonl(saved_job(args[2]).pages),
        create_mode=CreateNew,
      )
      println("JSONL exported")
    }
    "help" | "--help" | "-h" => usage()
    _ => raise @core.Invalid("unknown command; use --help")
  }
}

///|
async fn main {
  dispatch(@env.args())
}
