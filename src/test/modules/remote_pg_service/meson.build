# Copyright (c) 2025, PostgreSQL Global Development Group

tests += {
  'name': 'oauth_validator',
  'sd': meson.current_source_dir(),
  'bd': meson.current_build_dir(),
  'tap': {
    'tests': [
      't/001_remote_service_file.pl',
    ],
    'env': {
      'PYTHON': python.path(),
      'with_libcurl': libcurl.found() ? 'yes' : 'no',
      'with_python': 'yes',
    },
  },
}
