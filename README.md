restful_sketches
================

A couple of quick and dirty RESTful services

Both of these are done with Dancer apps, and most of the
files are just the default files generated from Dancer -a Restful::Foo

The spellcheck uses aspell.  You can hit it with 

/check/foo.json

and it will give you spelling suggestions for "foo", returned in JSON
serialization.  Or you can get it serialized as XML or YAML, by putting
.xml or .yml on the end.

You can specify the dictionary you want to look in, if more than one are
available.  A list of available dictionaries is retrievable with a GET to
/dictionaries/list

The language is defaulted to en_US, but you can put a ?language=es at the
end of your url to get Spanish (if you have that dictionary available).

The response is extensible--it returns a hash (or whatever the format's
equivalent is) with the list of results, and a boolean for whether the
word matched anything in the dictionary (aspell will give you some
guesses anyway, if you want them, even if the word exists). 


