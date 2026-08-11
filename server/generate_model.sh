#!/bin/bash

sea-orm-cli generate entity \
--with-serde both \
--with-prelude none \
--big-integer-type i64 \
--output-dir src/model 
# --experimental-preserve-user-modifications 
