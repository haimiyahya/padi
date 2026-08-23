import Config

# Development-specific configuration

config :padi, :ramdisk,
  path: "/tmp/padi_ramdisk_dev"

# Enable more verbose logging in development
config :logger, level: :debug
