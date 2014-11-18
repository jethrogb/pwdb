Password manager
================

This is a web-based password database.
The purpose is to provide a simple way to display and record passwords online.

The software is written in Ruby for Common Gateway Interface (CGI).
The storage backend is GPG-encrypted YAML.
Tested with Ruby 1.9.3. and GPG 1.4.11.
The following Ruby modules are required: cgi, erb, base64, yaml, fileutils.

