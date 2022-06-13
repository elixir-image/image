paths = Path.wildcard("test/support/did_not_match/**/*.{png,tif,jpg}")
Enum.each(paths, &File.rm/1)

Application.ensure_all_started(:telemetry)
Application.ensure_all_started(:hackney)

ExUnit.configure(exclude: [full: true, stream: true])
ExUnit.start()
