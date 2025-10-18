#!/usr/bin/perl
my $VERSION=1;

use XML::Feed;
use LWP::Protocol::https;
use strict;
use Getopt::Std;

getopts('hf:r:e:');
our ($opt_e,$opt_f,$opt_r, $opt_h);       HELP_MESSAGE() if $opt_h; 
my $count;
my $feed_url = defined($opt_f) ? $opt_f : HELP_MESSAGE();   
my $blogroot = defined($opt_r) ? $opt_r : HELP_MESSAGE();
my $entry_count = defined($opt_e) ? $opt_e : 5;

#------------------------------------

my $feed = XML::Feed->parse(URI->new($feed_url)) or die XML::Feed->errstr;
warn "Found feed titled ", $feed->title, ".\n";

for my $entry ($feed->entries) {
  $count++; my @tags;
  warn "$count: Found entry titled ", $entry->title, ", with an ID of ", $entry->id, ".\n";

  write_entry($entry->title, $entry->content->body, $entry->issued->ymd,$blogroot,$entry->id,$entry->category);
  last if $count == $entry_count;
}

#Notes to myself, because I'll probably forget:
#$feed->entries returns an array containing XML::Feed::Entry objects.
#Those Entry objects then contain "Content" which are XML::Feed::Content objects. 



#Subroutines--------------------------

sub write_entry {
  my ($title,$content,$date,$root,$id,$category,@tags) = @_;       
  my $filename = getfilename($title,$date,$root);
  $content = parse_html($content);
  my $yaml_tags = join "\n  - ", @tags;

  my $front_matter = 
qq(---
title: \"$title\"
date: $date
draft: false
categories: '$category'
tags:
  - $yaml_tags
---

);
  if (-e $filename) {
    warn "\tEntry $title already exists\n";
    open (my $blog, '<',$filename) or die "Found $filename but cannot open it\n";
    my $existing = do {local $/ = undef; <$blog>};   #slurp in the file as a single string
    if ($content eq $existing) {
      warn "\tNo changes to $title, skipping\n";
      close $blog;
      return;
    }
    warn "\tUpdating contents of $title\n";
  }
    open (my $blog, '>',$filename) or die "failed to create file $filename\n";
    print $blog $front_matter.$content; warn "\tWriting to  $filename\n";
    close $blog;
}

sub getfilename {
  my ($title,$date,$root) = @_; 
  $title =~ s/[<>:"\/\\'!|?* \(\)]//g; #Strip out stuff that shouldn't be in a filename
  return($root.substr($date."_".$title, 0,25).".html");
}

sub parse_html {     
  #This assumes that source images were stored in /public/.     
  $_[0] =~ s/<img\s+src="[^"]*\/public\/([^"]+\.(?:png|jpe?g|gif|webp))"\s+alt="([^"]+)"[^>]*>/<img src="\/img\/$1" alt="$2">/gi;
  return $_[0];
}

sub HELP_MESSAGE {
print <<EOF;

DESCRIPTION

This program extracts post titles, dates and body content from a blog's
RSS feed and then creates a series of plain files. Each file is titled 
with the date and post title, and the post content is written to the 
file in a way that Hugo -should- be able to understand. 

I originally created this for the purpose of automatically mirroring a 
dotclear blog to a gopherhole, but modified it to create files for hugo instead.

USAGE

rss-to-hugo [OPTIONS]

The following options are supported: 

-r [path]   Required to specify the destination path
-f [feed]   Required to specify the RSS feed address (in double quotes)
-e [number] Optional to specify the number of RSS entries to review. Default=5.
-h|--help   Print this message and exit. 

Note: Depending on the feed, this script may pull a large number of entries
each  time it is run. You may be able to limit this by requesting a reduced 
feed via API or adjusting the feed settings if you control the feed. 
Setting -e does NOT  change how many entries are received from the RSS feed,
it only determines how many of the received entries are processed. 
EOF
  exit;
}

sub VERSION_MESSAGE {
  print <<EOF;
rss-to-hugo - Version $VERSION.
Written by Adam Behr
EOF
  exit;
}