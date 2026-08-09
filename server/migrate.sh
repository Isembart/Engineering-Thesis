#!/bin/bash

sea-orm-cli generate entity \
--with-serde both \
--output-dir src/model 
--big-integer-type i64 \
# --experimental-preserve-user-modifications 
