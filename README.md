# dictionary-explorer

Command line Ruby script to (1) do a regex search of dictionary words and (2) find all words that are permutations of any subset of a set of given letters (Scrabble style)

## Installation

This only works on a Unix/Linux-style system, on the command line. If you aren't
comfortable with the command line, maybe you shouldn't bother with this.

Install Ruby if not already in your system (to test, type `ruby -v`).

Once installed, install the one requirement: `gem install highline`.

Then simply type `ruby dexplore.rb` and read the on-screen instructions to begin.

## Issues

The word list *is not* equivalent to the permissible Scrabble words.

It probably is missing some words. It is known to be missing the word 'dang',
which I thought was funny.

There are probably bugs and infelicities. This was just a learning project so
your mileage may vary.

