import Config

config :ex_aws,
  region: "local"

config :ex_aws, :s3,
  access_key_id: System.get_env("MINIO_ACCESS_KEY"),
  secret_access_key: System.get_env("MINI_SECRET"),
  region: "local",
  scheme: "http://",
  host: "127.0.0.1",
  port: 9000

config :nx,
  default_backend: EXLA.Backend

