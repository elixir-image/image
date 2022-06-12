import Config

config :ex_aws,
  region: "local"

config :ex_aws, :s3,
  access_key_id: "nEM6SUTr9BLgqRVP",
  secret_access_key: "s9QKLbR1bACI5o892HoPmgKBasJuNsFf",
  region: "local",
  scheme: "http://",
  host: "127.0.0.1",
  bucket: "images",
  port: 9000