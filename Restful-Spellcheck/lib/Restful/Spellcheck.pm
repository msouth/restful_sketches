package Restful::Spellcheck;
use strict;
use warnings;
use Dancer ':syntax';
use Dancer::Plugin::REST;
use Dancer::Error;
use Text::Aspell;
# note that serialization via XML
# will not work without requires XML::Simple

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

# store the dictionaries available on the 
# system.  Requires restart to get new
# dictionaries listed.  Probably we aren't
# adding new dictionaries very often though.
my @dictionaries;

{
    my $sp =  Text::Aspell->new;
    @dictionaries = $sp->list_dictionaries;
    s/:.*// for @dictionaries;
}

my $speller; 

# automatically serialize according to 
# extension requested
prepare_serializer_for_format;

hook 'before' => sub {
    # we need a new $speller every time, because 
    # Text::Aspell can't set language twice on 
    # one speller object (!)
    $speller =  Text::Aspell->new;
    my $lang = 'en_US';

    if ( my $alt_lang = param('language') ) {
        debug('an alternate language has appeared...');
        
        if ( grep $_ eq $alt_lang, @dictionaries ) {
            $lang = $alt_lang;
            debug('..and I recognize it');
        }
        else {
        debug( "... whoops, I don't recognize $alt_lang");
            return my $error = Dancer::Error->new(
                code    => 424,
                message => "No aspell dictionary on this system matching [$alt_lang].  See /dictionaries/list.". param('format'),
            )->render;
        }
    }
    $speller->set_option( lang => $lang );
};

get '/check/:word.:format' => sub {
    my $language = $speller->get_option( 'lang' );
    debug( 'checking word '. param('word'). 'using language '. $language);
    my $response = {
        language => $language,
        check => $speller->check(param('word')),
    };

    my $max_suggestions = param('max_suggestions') || 3;
    if( not $response->{check} or param('always_suggest') ) {

        debug( 'getting suggestions for word '. param('word'). 'using language '. $language);
        my @guesses = $speller->suggest( param('word') );

        # this splice setting could be tweaked, made optional upon parameterization, sent as short_list and full_list, or completely left out
        $response->{suggestions} = [ splice( @guesses, 0, $max_suggestions ) ];
    }

    $response;
};

get '/dictionaries/list.:format' =>  sub {
    {
        dictionaries => \@dictionaries,
    };
};

true;
