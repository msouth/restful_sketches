package Restful::Thumbs;
use strict;
use warnings;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Database;
use Dancer::FileUtils qw/dirname path/;

use Image::Grab;
use Image::Info;
use Image::Magick;
use File::Temp;
use File::Path;
use v5.10;


our $VERSION = '0.1';

#########################################
#               routes                  #
#########################################

get '/' => sub {
    template 'index';
};

get '/thumb/:url_id/:size.:ext' => sub {
    my $file_location = cache_file_location();

    # see if there's anything at the location.  If not, we'll
    # try to generate it (kinda violates REST a big, but once 
    # generated, it will always be returning this
    unless (-e "public/$file_location") {
        my $db_url = db_url( param( 'url_id' ) );
        return send_error( "the url id ".param('url_id')." does not exist in the url database.  Try again with thumb/generate and a url parameter") unless ref $db_url;
        #XXX do we actually need to explicitly pass along the size and ext? Generate will be looking for them
        # anyway in the param...need to test that
        forward '/generate/thumb', { url => $db_url->url, size=>param('size'), ext=>param('ext')};
    }
    # serve the file
    debug( "sending $file_location, hope that exists in public/" );
    return send_file $file_location;
};

any[ 'post', 'get'] => '/generate/thumb' => sub {


    my $url = param('url') or return send_error("You must set a 'url' parameter to generate the thumbnail from", 400);
    my $size = param('size') || '100x100';
    my $ext = param('ext'); # we will default to the url's type unless asked to use something else
    $ext = normalize_ext($ext);

    debug( "url: [$url], size:$size, ext: $ext" );
    # look up the url in the db--does find_or_create, so this should aways succeed
    my $db_url = db_url( $url );
    # might have the extension at this url saved
    if ( not $ext ) {
        $ext = $db_url->ext; # it's still possible that we don't have a value here--might have just created this record
    }
    my $url_id = $db_url->id;
    my $cache_file; # the cache file for this url, size, and extension
    if ($ext) {
        $cache_file = cache_file_location( url_id=> $url_id, size=>$size, ext=>$ext );
        # this probably needs the ability to force a refresh of the cache.  Maybe POST could always do it and
        # GET would only do it if there's no cache available, or just make a "force_refresh" param.  Might
        # also accomplish cache expiration with a DELETE, the unloved and neglected REST method
        if (-e $cache_file) {
            debug( "cache file for this already exists: [$cache_file]" );
            send_file $cache_file;
        } else {
            debug( "no file at [$cache_file], let's create it" );
            #XXX or we could conditionally return a 404 on a GET to be RESTfully religious about
            # not changing anything on a GET. We could require a POST if you're going to make anything
            # that doesn't exist.  That might be a little pedantic, but it's possible that
            # the people using the service *want* to know if a file exists without creating it, so
            # a 404 might be desired from the GET.
            #
            # that logic would go here if we wanted it.
        }
    }

    my $pic = new Image::Grab;
    $pic->url( $url );
    $pic->grab;


    my $data = $pic->image;

    # originally did this all in memory w/Image::Resize, but found that
    # GD had a problem where it got transparent backgrounds
    # wrong in some cases.  Left the Image::Grab in there
    # for the claimed benefit that it does a good job pulling
    # images from various kinds of servers, and now this clunky
    # code lets me read it in for Image::Magick.  Also there's
    # a chance we would want to md5sum it or whatever for later
    # optimizations/cache walks, maybe this would end up being
    # done anyway.
    my ($fh, $fname) = File::Temp::tempfile;
    binmode $fh;
    print $fh $data;
    close $fh;
    debug "tmp image is written to $fname btw";

    # gives (all caps) jpeg, gif, png, etc at $type->{file_type}
    my $type = Image::Info::image_type( \$data);
    debug Dumper($type) ; use Data::Dumper;

    my $original_ext = normalize_ext( $type->{file_type} );

    debug ( "after calling normalize with $type->{file_type}, original_ext is [$original_ext]");

    $db_url->ext( $original_ext ); # this is the format of the image at the url, save or update it
    $db_url->update;
    
    # Magick may be more of a pain to install and slower, but at least
    # it's not giving me black backgrounds in regions that used to be 
    # transparent in the original
    my $mgk = Image::Magick->new;
    $mgk->ReadImage( $fname );
    my $clone = $mgk->Clone;
    my ($width, $height) = split 'x', $size;
    $clone->Scale( width=>$width, height=>$height);

    $cache_file = cache_file_location( url_id=> $url_id, size=>$size, ext=>$ext );
    my $dir = dirname( $cache_file );

    debug( "making [public/$dir] unless -d, which returns:". -d "public/$dir" );
    File::Path::make_path( "public/$dir" ) unless -d "public/$dir";

    my $ret = $clone->Write("public/$cache_file");
    # note--it's the stringified version of $ret that will be true (and contain an error message) on 
    # failure.  The non-interpolated version is true on success.
    
    die "Image Magick write failed: [$ret]" if "$ret";

    debug "I just told IM to write to $cache_file, and btw pwd is ". qx/ pwd /;

    # redirecting here because the client can use the simpler url in the future, and modify it to get
    # other formats or sizes with the cleaner url
    redirect path( 'thumb', $url_id, "$size.$ext" );
    send_file $cache_file ;
    
};

#########################################
#              helpers                  #
#########################################

sub cache_file_location {
    my %args = @_;
    debug Dumper(\%args); use Data::Dumper;
    my $four_hundred = sub { send_error( shift, 400 ) };
    my $url_id = $args{url_id} || param( 'url_id' ) || $four_hundred->("no url_id");
    my $size   = $args{size}   || param( 'size' )   || $four_hundred->("no size given");
    my $ext    = $args{ext}    || param( 'ext' )    || $four_hundred->("need a three letter extension");
    return my $file_location = path( config->{cache_root} || 'thumb_cache' , $url_id, $size . '.' . $ext);
}

# retrieve the metadata about this url from the database.  Also creates an entry the
# first time a url is seen.
sub db_url {
    my $url_or_id = shift;
    # yeah, I'm using redneck polymorphism here.  But seriously, we know what we've got just
    # by looking in this case.  Probably wouldn't want to leave it this way for production.
    if ($url_or_id =~ /^\d+$/) {
        return my $db_url = schema('default')->resultset('Url')->find({id=>$url_or_id});
    } 
    else {
        return my $db_url = schema('default')->resultset('Url')->find_or_create({url=>$url_or_id});
    }
}

# allow people/libraries to pass JPEG, PNG, etc--normalize to lowercase and three letters
sub normalize_ext {
    my $ext = shift or return;
    $ext = lc $ext;
    $ext =~ s/jpeg/jpg/;
    return $ext;
}

# created the database the first time
sub init_db {
    database->do( "CREATE TABLE IF NOT EXISTS url( id INTEGER  PRIMARY KEY AUTOINCREMENT, url CHAR UNIQUE, ext CHAR, updated NOW DEFAULT CURRENT_TIMESTAMP)" );
}


#########################################
#              startup                  #
#########################################


init_db();
start;
true;
