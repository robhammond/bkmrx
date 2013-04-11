#!/usr/bin/env perl
use strict;
use File::Spec::Functions qw( catfile );
use File::Path qw(make_path);
use Lucy::Plan::Schema;
use Lucy::Plan::FullTextType;
use Lucy::Analysis::PolyAnalyzer;
use Lucy::Index::Indexer;
use Lucy::Search::QueryParser;
use Lucy::Search::TermQuery;
use Lucy::Search::ANDQuery;
use Getopt::Long;
use FindBin;
use Mojo::Log;
my $log = Mojo::Log->new;

my $path_to_index = "$FindBin::Bin/../web-index";
my $corpus_source = "$FindBin::Bin/../corpus";

# Ensure index directory exists
make_path( "$path_to_index", {verbose => 1,mode => 0755,});

my $create = 0;
# Run with --create=1 to recreate the index from scratch
# Default is to update index
GetOptions( 'create=i' => \$create, 'corpus_source=s' => \$corpus_source );

# Create Schema.
my $schema = Lucy::Plan::Schema->new;

# Set options for index
my $case_folder  = Lucy::Analysis::CaseFolder->new;
my $tokenizer    = Lucy::Analysis::RegexTokenizer->new;
my $stemmer      = Lucy::Analysis::SnowballStemmer->new( language => 'en' );
my $stopfilter   = Lucy::Analysis::SnowballStopFilter->new( 
    language => 'en',
);

my $polyanalyzer = Lucy::Analysis::PolyAnalyzer->new(
    analyzers => [ $case_folder, $tokenizer, $stemmer, $stopfilter ], 
);

# set field types for schema
my $title_type = Lucy::Plan::FullTextType->new( 
    analyzer => $polyanalyzer,
    highlightable => 1,
    boost    => 15,
);

my $content_type = Lucy::Plan::FullTextType->new(
    analyzer      => $polyanalyzer,
    highlightable => 1,
);
my $url_type = Lucy::Plan::StringType->new( indexed => 1, );

$schema->spec_field( name => 'url',      type => $url_type );
$schema->spec_field( name => 'title',    type => $title_type );
$schema->spec_field( name => 'content',  type => $content_type );

# Create an Indexer object.
my $indexer = Lucy::Index::Indexer->new(
    index    => $path_to_index,
    schema   => $schema,
    create   => $create,
    truncate => $create,
);

# Collect names of source files.
opendir( my $dh, $corpus_source )
    or die "Couldn't opendir '$corpus_source': $!";
my @filenames = grep { $_ =~ /\.xml/ } readdir $dh;

# Exit if there's zero files
# (Should be redundant if called from crawl script)
if ($#filenames == 0) { exit; }

# Iterate over list of source files.
for my $filename (@filenames) {
    # check if file is locked first (ie by another indexing process)
    # if not, lock it then use it, if so go on to next file
    $log->info("Indexing $filename");
    my $doc = parse_file($filename);
    $indexer->add_doc($doc);
    # remove file if it's been indexed
    if ($doc) {
        # system("rm " . catfile( $corpus_source, $filename ));
    }
}

# Finalize the index and print a confirmation message.
$indexer->commit;
$log->info("Finished indexing");

# return a hashref with the fields title, body, url, etc.
sub parse_file {
    my $filename = shift;
    my $filepath = catfile( $corpus_source, $filename );
    open( my $fh, '<:utf8', $filepath ) or die "Can't open '$filepath': $!";
    my $text = do { local $/; <$fh> };    # slurp file content
    
    $text =~ /<uri>(.*?)<\/uri><title>(.*?)<\/title><content>(.*?)<\/content>/ms 
        or die "Can't extract title/bodytext from '$filepath'";
    my $uri      = $1;
    my $title    = $2;
    my $bodytext = $3;
    
    return {
        url      => $uri,
        title    => $title,
        content  => $bodytext,
    };
}

