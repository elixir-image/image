paths = Path.wildcard("test/support/did_not_match/**/*.{png,tif,jpg}")
Enum.each(paths, &File.rm/1)

ExUnit.configure(exclude: [full: true])
ExUnit.start()
