#!/usr/bin/env ruby -w
require 'highline'

# This is a simple Ruby script that reads from the local (*nix) dictionary
# (assuming it exists at /usr/share/dict/words) and allows users to search
# the word list with regexen, returning matches.

# Clear the console.
system 'clear'

# Load local dictionary
begin
  DICT = File.readlines('/usr/share/dict/words.pre-dictionaries-common')
rescue Errno::ENOENT
  puts "\n  Sorry, this script couldn't be run because the expected dictionary"
  puts "  doesn't exist. Many Unix-type systems have a dictionary located at"
  puts "  /usr/share/dict/words, but this system doesn't.\n\n"
  exit
end
DICT.reject! {|w| /\A[A-Z]/ =~ w}
DICT.reject! {|w| /[\'-]/ =~ w}
puts "Dictionary loaded."

INPUTS = %w|h ? help q| # These are commands the user can use; this should be
                        # collected automatically, but I don't know how yet.

# Scrabble lookup feature
# Strategy: you're going to return a DICT word (word) only if every letter
# in the word is in the user-input letters (input). It doesn't matter if some
# input letters are left over.

# Construct $patterns.
# Rewrite words with letters in alpha order; e.g., capstan => aacnpst
$patterns = {}
DICT.each do |word|
  word = word.chomp
  # Save the words this way: <pattern>: [array of words that are permutations]
  pattern = word.downcase.split(//).sort.delete_if {|l| /[^\w]/ =~ l }.join
  if $patterns[pattern].nil?
    # Initialize this pattern.
    $patterns[pattern] = [word]
  else
    # Add word to this pattern list.
    $patterns[pattern] << word
  end
end
puts "Patterns loaded.\n\n"

intro = <<ENDOFINTRO
===============================
Welcome to Dictionary Explorer!

This app does two kinds of searches.

1. Word match search:
Type any sequence of letters, and get back words in the dictionary that match
that sequence (in that order). You can use regular expressions (Ruby syntax).

Example: search for 'berg'. Results:
10 found.
ambergris, berg, bergs, fiberglass, flabbergast, flabbergasted,
flabbergasting, flabbergasts, iceberg, icebergs

2. Scrabble search:
If you start your search with a forward slash (/) followed by some letters,
then you'll get back a list of words that use of those letters (in any order).

Example: search for '/asdf'. Results:
7 found.
Words you can make with these letters:
fads, ads, fad, sad, ad, as, fa

To quit, type '/q' (without the quotation marks).
===============================

ENDOFINTRO
puts intro


#########################
# Query object holds all the features needed to return results to user for
# a query.
class Query
  attr_accessor :pattern, :results, :scrab

  def initialize(args)
    if args[:pattern]
      @pattern = args[:pattern]
      search_words
    elsif args[:scrab]
      @scrab = args[:scrab]
      scrab_words
    end
  end

  # With an input of a word (which is treated as a regex) or regex, search
  # every word in DICT
  def search_words
    begin
      regex = Regexp.new(@pattern)
    rescue RegexpError => msg
      error_msg(msg)
    rescue NameError => msg
      error_msg(msg)
    end
    @results = DICT.select do |word|
      regex =~ word
    end
    @num_results = @results.length
    format_results
    display_results
  end

  def error_msg(msg)
    puts "\n  That isn't a well-formed regular expression: #{msg}\n\n"
  end

  def format_results
    @results = @results.map(&:chomp).join(', ')
    @results = wrap(@results)
    @results = num_found + @results
  end

  def display_results
    if @num_results > 400
      write_to_temp_file
      display_temp_file
    elsif @num_results > 0
      puts @results
    else
      puts "No results found.\n\n"
    end
  end

  def wrap(s, width=78)
    s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
  end

  def write_to_temp_file
    system('rm temp.txt') if File.exist?('temp.txt')
    File.open('temp.txt', 'a') do |f|
      f.write(@results)
    end
  end

  def display_temp_file
    system('less temp.txt')
    puts num_found
  end

  def num_found
    "#{@num_results} found.\n"
  end

  def scrab_words
    permutations = prepare_permutations_of_scrab
    compile_scrab_words(permutations)
    order_scrab_words
    @results.uniq!
    display_scrab_words
  end

  def prepare_permutations_of_scrab
    # From @scrab (scrabble search letters), construct array of possible
    # patterns (permutations). E.g., if @scrab = 'abcd', then array =
    # %w[a ab abc abcd abd acd ad b bc bcd bd c cd d]
    scrab_arr = @scrab.split(//).sort
    permutations = []
    long = (scrab_arr.length > 10 ? true : false)
    print "Preparing permutations: " if long
    (@scrab.length + 1).times do |n|
      next if n == 1
      permutations.concat(scrab_arr.combination(n).to_a)
      print "." if long
    end
    puts "" if long
    return permutations
  end

  def compile_scrab_words(permutations)
    @results = []
    permutations.each do |perm|
      perm = perm.join
      @results.concat($patterns[perm]) if $patterns[perm]
    end
  end

  def order_scrab_words
    @results = @results.sort do |a, b|
      [b.size, a] <=> [a.size, b]
    end
  end


  def display_scrab_words
    # Finally, sort the matching words first by length and then by alpha within
    # length.
    puts "#{@results.length} found."
    puts "Words you can make with these letters:"
    puts wrap(@results.join(', ')) + "\n"
  end

end

#########################
# Permit user input
class GetInput

  attr_accessor :query

  def initialize
    get_input
  end

  def get_input(*pattern)
    print "Input word or pattern: "
    input = pattern[0] ?
      ask_with_pattern(pattern[0]) :    # If argument, offer to search again;
      gets.chomp                        # otherwise, just get input.
    dispatch_table(input)               # Handle input.
    get_input                           # Unending loop...
  end

  def dispatch_table(input)
    regex = Regexp.union(INPUTS)
    if input.empty?
      puts "You searched for nothing, so we found nothing."
    elsif /\A#{regex}\Z/i =~ input ||     # Help commands and q
          /\A\//          =~ input ||     # Commands starting with /
          /\A\/\//        =~ input ||     # // (search again)
          /\x1B\[A/       =~ input        # Up arrow (search again)
      process_command(input)              # Handle these differently
    else
      @query = Query.new(pattern: input)  # Search for matching words
    end
  end

  def ask_with_pattern(pattern)
    cli = HighLine.new
    cli.ask("enter to search again=>") {|q| q.default = pattern}
  end

  def process_command(input)
    if /\A(\/q|q)\Z/ =~ input
      puts "Bye!"
      exit
    elsif (defined? @query)
      if (/\A\/\// =~ input || /\x1B\[A/ =~ input)
        get_input(@query.pattern)
      elsif (/\A\/(\w+)\Z/ =~ input)
        @query = Query.new(scrab: $1)
      end
    end
  end

end

GetInput.new

# Add features for mixing up letters to form words
