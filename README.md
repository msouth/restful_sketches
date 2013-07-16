restful_sketches
================

A couple of quick and dirty RESTful services

Both of these are done with Dancer apps, and most of the
files are just the default files generated from 

    Dancer -a Restful::Foo

-------------------------

# Restful::Spellcheck #

The spellcheck uses aspell.  You can hit it with a GET to 

    /check/foo.json

and it will give you spelling suggestions for "foo", returned in JSON
serialization.  Or you can get it serialized as XML or YAML, by putting
`.xml` or `.yml` on the end.

You can specify the dictionary you want to look in, if more than one are
available.  A list of available dictionaries is retrievable with a GET to
`/dictionaries/list`

The language is defaulted to `en_US`, but you can put a `?language=es` at the
end of your url to get Spanish (if you have that dictionary available).

The response is extensible--it returns a hash (or whatever the format's
equivalent is) with a boolean value called 'check' which will be a one or
a zero depending on whether the word was found in the dictionary.  If the
value of check is zero, the word was not found, and there will be another
key called 'suggestions' with a list of suggested spellings.

For example:


    host% curl localhost:3000/check/colour.json
    {
       "language" : "en_US",
       "suggestions" : [
          "co lour",
          "co-lour",
          "col our"
       ],
       "check" : 0
    }

but

    host% curl localhost:3000/check/colour.json?language=en_GB
    {
       "language" : "en_GB",
       "check" : 1
    }

Other parameters include "max_suggestions" to give more than whatever
the configured default number of suggestions is, and "always_suggest" 
to indicate that you want suggestions for the word even if the word 
is found in the dictionary.

The default_max_suggestions configuration option sets the default
value in absence of a max_suggestions parameter--in absence of the
config setting it defaults to three suggestions.

Requesting a language that doesn't exist gives you a message
telling you how to get the list of available dictionaries.

See Makefile.PL for required modules, some of which will
require libraries or binaries (e.g. aspell).
-------------------------

# Restful::Thumbs #

This service is a bit more involved.  Given a url, a requested size,
and an optional image format (specified as a three letter extension),
it will return a thumbnail generated from the image at the given
url.

The urls are stored in a SQLite database, and the thumbnails are
cached in the public/ diretory of the application under a directory
called thumb_cache/.  A request that can be satisfied with an already
generated file will simply send that static file.

When a thumbnail is created, a 301 redirect is sent and the client
can take the url sent in the Location header of the redirect to be
the location of the thumbnail for future reference.

The cached images can also be used as a basis for other versions
of the thumbnail.  If you know that you need several sizes or perhaps
a single thumbnail in a different format, you can request it as if
it's there, and it will be generated and returned.

All generation of thumbnails is done by retrieving the original
image and creating a thumbnail from it.  (If the original image is
not available, no attempt is made to stretch or shrink an existing
thumbnail to accommodate, it just fails.)  As long as the images
are being sources from a reliable service, this works to our advantage
because the thumbnail is always using the most recent version of
the picture.


    host$ curl -v localhost:3000/generate/thumb?url='https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/Baby_turtles_swimming_Sri_Lanka.jpg/800px-Baby_turtles_swimming_Sri_Lanka.jpg' > bob.jpg
    * About to connect() to localhost port 3000 (#0)
    *   Trying 127.0.0.1...
      % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                     Dload  Upload   Total   Spent    Left  Speed
      0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0* connected
    * Connected to localhost (127.0.0.1) port 3000 (#0)
    > GET /generate/thumb?url=https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/Baby_turtles_swimming_Sri_Lanka.jpg/800px-Baby_turtles_swimming_Sri_Lanka.jpg HTTP/1.1
    > User-Agent: curl/7.24.0 (x86_64-apple-darwin12.0) libcurl/7.24.0 OpenSSL/0.9.8x zlib/1.2.5
    > Host: localhost:3000
    > Accept: */*
    > 
      0     0    0     0    0     0      0      0 --:--:--  0:00:01 --:--:--     0* HTTP 1.0, assume close after body
    < HTTP/1.0 301 Moved Permanently
    < Location: http://localhost:3000/thumb/7/100x100.jpg
    < Server: Perl Dancer 1.3116
    < Content-Length: 5784
    < Content-Type: image/jpeg
    < Last-Modified: Tue, 16 Jul 2013 06:13:43 GMT
    < X-Powered-By: Perl Dancer 1.3116
    < 
    { [data not shown]
    100  5784  100  5784    0     0   4889      0  0:00:01  0:00:01 --:--:--  4897
    * Closing connection #0

At the end of this interaction, the command line redirect target
"bob.jpg" holds the requested thumbnail (in the default 100x100
size, and in jpeg format, because the source was a jpeg).  But the url in
the Location: header can be used to access that file from now on.

From this point forward, it is also possible to request, for example,
`http://localhost:3000/thumb/7/100x100.png` to get a png version or
`http://localhost:3000/thumb/7/300x300.jpg` to get a larger jpeg.

'size' and 'ext' parameters may also be put into the query string
(or post data) in `/generate/thumb` calls if the client wishes to
override the default settings mentioned above.

Unimplemented features:  A PUT that would allow a client to
override a thumbnail directly if there were some sort of issue that
needed to be corrected.  A DELETE to remove a cached file and force
it to be re-created.  (For that matter, just a query string
parameter could say 'force_recreate" or something would also work).

See Makefile.PL for required modules, some of which will
require libraries or binaries (e.g. Image Magick).
