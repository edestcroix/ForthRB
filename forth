#! /usr/bin/env ruby
# frozen_string_literal: true

require_relative 'interpreter'

# if the program is called with an argument,
# open the file and use it as input.

source = if (filename = ARGV[0])
           Source.new(File.open(filename), alt_print: true)
         else
           Source.new($stdin)
         end
ForthInterpreter.new(source).interpret
