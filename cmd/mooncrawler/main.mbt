///|
fn usage() -> Unit {
  println(
    "MoonCrawler 0.3.0\n  init CONFIG.json\n  validate CONFIG.json\n  crawl CONFIG.json JOBDIR SEED [SEED ...]\n  crawl-sitemap CONFIG.json JOBDIR SITEMAP_URL\n  crawl-robots CONFIG.json JOBDIR SITE_URL\n  recrawl CONFIG.json NEW_JOBDIR PREVIOUS_JOBDIR SEED [SEED ...]\n  resume JOBDIR\n  resume-recrawl JOBDIR PREVIOUS_JOBDIR\n  pause JOBDIR\n  status JOBDIR\n  stats JOBDIR\n  export JOBDIR OUTPUT.jsonl",
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
async fn saved_job(directory : String) -> (@storage.Snapshot, Int32) {
  guard @storage.read_job_metadata(directory) is Some(saved) else {
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
  discovery? : (String, Bool),
  previous_job? : String,
) -> Unit {
  let store = @storage.FileStore::open(directory)
  defer store.close()
  let state = store.load_metadata()
  if resume_job && state is None {
    raise @core.Storage("no checkpoint found in job directory")
  }
  let config = match config {
    Some(c) => c
    None =>
      match state {
        Some((s, _)) => s.config
        None => raise @core.Storage("no checkpoint found in job directory")
      }
  }
  if !resume_job && state is Some(_) {
    raise @core.Invalid("job already exists; use resume or another directory")
  }
  let program = @env.get_env_var("MOONCRAWLER_CURL").unwrap_or("curl")
  let fetcher : @fetcher.CurlFetcher = { program, }
  let engine = @engine.Engine::new_streaming(config, fetcher, store, state?)
  let previous = match previous_job {
    Some(path) => Some(@storage.PageReader::open(path))
    None => None
  }
  defer (if previous is Some(reader) { reader.close() })
  if previous is Some(reader) {
    engine.use_previous(reader, fetcher)
  }
  if discovery is Some((source, via_robots)) {
    let added = if via_robots {
      engine.discover_robots_sitemaps(source)
    } else {
      engine.discover_sitemap(source)
    }
    if added == 0 {
      raise @core.Policy("no eligible Sitemap URLs")
    }
    println("queued \{added} Sitemap URLs")
  }
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
    "saved \{engine.page_count()} pages; succeeded=\{engine.frontier.count(Succeeded)} failed=\{engine.frontier.count(PermanentlyFailed)} pending=\{engine.frontier.count(Pending) + engine.frontier.count(RetryPending)}",
  )
  if @env.get_env_var("MOONCRAWLER_JSON_METRICS") == Some("1") {
    println(engine.metrics().stringify())
  }
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
    "crawl-sitemap" | "crawl-robots" => {
      guard args.length() == 5 else {
        raise @core.Invalid("Sitemap crawl requires CONFIG.json JOBDIR URL")
      }
      crawl(
        Some(config_file(args[2])),
        args[3],
        [],
        false,
        discovery=(args[4], args[1] == "crawl-robots"),
      )
    }
    "recrawl" => {
      guard args.length() >= 6 else {
        raise @core.Invalid(
          "recrawl requires CONFIG.json NEW_JOBDIR PREVIOUS_JOBDIR SEED",
        )
      }
      crawl(
        Some(config_file(args[2])),
        args[3],
        args[5:].to_owned(),
        false,
        previous_job=args[4],
      )
    }
    "resume-recrawl" => {
      guard args.length() == 4 else {
        raise @core.Invalid("resume-recrawl requires JOBDIR PREVIOUS_JOBDIR")
      }
      crawl(None, args[2], [], true, previous_job=args[3])
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
      let (saved, count) = saved_job(args[2])
      let counts : Map[String, Int32] = Map([])
      for task in saved.tasks {
        let state = @json.to_json(task.state).stringify()
        counts[state] = counts.get(state).unwrap_or(0) + 1
      }
      let output : Map[String, Json] = {
        "version": @json.to_json(saved.version),
        "saved_at": @json.to_json(saved.saved_at),
        "pages": @json.to_json(count),
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
      let reader = @storage.PageReader::open(args[2])
      defer reader.close()
      reader.export_jsonl(args[3]) |> ignore
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
