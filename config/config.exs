import Config

# Ramdisk configuration
config :padi, :ramdisk,
  path: System.get_env("PADI_RAMDISK_PATH", "/tmp/padi_ramdisk")

# LadybugDB configuration
config :padi, :ladybug,
  db_path: Path.join([
    System.get_env("PADI_RAMDISK_PATH", "/tmp/padi_ramdisk"),
    "graph.lbug"
  ]),
  pool_size: 5

# Tree-sitter configuration
config :padi, :tree_sitter,
  grammars_path: Path.join(["#{__DIR__}", "../priv/parsers/grammars"]),
  supported_languages: [:elixir, :rust, :javascript, :typescript, :python, :go, :java, :cpp, :c]

# Vector store configuration
config :padi, :vector_store,
  dimension: 1536,
  index_size: 10_000

# JSON-RPC configuration
config :padi, :json_rpc,
  transport: :stdio,
  max_request_size: 10_485_760  # 10MB
