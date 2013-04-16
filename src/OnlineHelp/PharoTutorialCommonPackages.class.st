Class {
	#name : #PharoTutorialCommonPackages,
	#superclass : #Object,
	#category : #'OnlineHelp-Tutorials'
}

{ #category : #documentation }
PharoTutorialCommonPackages class >> athensTutorial1 [

	^'# Athens Overview

## Athens Tutorial

There is an in image tutorial for Pharo 2.0 available:

	Gofer it smalltalkhubUser: ''Pharo'' project: ''Athens''; configuration; load.

	ConfigurationOfAthens loadVersion: ''2.0''.

	Gofer it smalltalkhubUser: ''Pharo'' project: ''Athens'';
 	    package:''Athens-Tutorial''; load.

	AthensTutorial new openWithSpec.

'
]

{ #category : #documentation }
PharoTutorialCommonPackages class >> athensTutorial2 [

	^'# More Infos

## Introduction

Athens is a new graphics API, currently under development. 

## How to load it

In Pharo 2.0 just open the configuration browser from the world menu
and load the package "NeoCSV".


## Web links

Here are some relevant links:

- <http://lists.gforge.inria.fr/pipermail/pharo-project/2013-April/077044.html>
- <https://code.google.com/p/pharo/wiki/Athens> 
- <http://www.pharocasts.com/2012/06/athens-and-native-boost-at-work.html>

'
]

{ #category : #documentation }
PharoTutorialCommonPackages class >> neoCSVTutorial1 [

	^'# CSV

*Sven Van Caekenberghe*

*June 2012*

*(This is a draft)*


CSV (Comma Separated Values) is a popular data-interchange format.
NeoCSV is an elegant and efficient standalone Smalltalk framework to 
read and write CSV converting to or from Smalltalk objects.   


## An introduction to CSV


CSV is a lightweight text-based de facto standard for human-readable tabular data interchange.
Essentially, the key characteristics are that CSV (or more generally, delimiter separated text data):

- is text based (ASCII, Latin1, Unicode)
- consists of records, 1 per line (any line ending convention)
- where records consist of fields separated by a delimiter (comma, tab, semicolon)
- where every record has the same number of fields
- where fields can be quoted should they contain separators or line endings

Here are some relevant links:

- <http://en.wikipedia.org/wiki/Comma-separated_values>
- <http://tools.ietf.org/html/rfc4180>

Note that there is not one single offical standard specification.


## NeoCSV


The NeoCSV framework contains a reader (NeoCSVReader) and a writer (NeoCSVWriter)
to parse respectively generate delimiter separated text data to or from Smalltalk objects.
The goals of this project are:

- to be standalone (have no dependencies and have little requirements)
- to be small, elegant and understandable
- to be efficient (both in time and space)
- to be flexible and non-intrusive

To use either the reader or the writer, 
you instanciate them on a character stream and use standard stream access messages.
Here are two examples:

    (NeoCSVReader on: ''1,2,3\4,5,6\7,8,9'' withCRs readStream) upToEnd.

    String streamContents: [ :stream |
      (NeoCSVWriter on: stream) 
        nextPutAll: #( (x y z) (10 20 30) (40 50 60) (70 80 90) ) ].


## Generic Mode


NeoCSV can operate in generic mode without any further customization.
While writing,

- record objects should respond to the #do: protocol
- fields are always send #asString and quoted
- CRLF line ending is used

While reading,

- records become arrays
- fields remain strings
- any line ending is accepted
- both quoted and unquoted fields are allowed

The standard delimiter is a comma character.
Quoting is always done using a double quote character.
A double quote character inside a field will be escaped by repeating it.
Field separators and line endings are allowed inside a quoted field.
All whitespace is significant. 


## Customizing NeoCSVWriter


Any character can be used as field separator, for example:

    neoCSVWriter separator: Character tab

or

    neoCSVWriter separator: $;

Likewise, any of the 3 common line end conventions can be set:

    neoCSVWriter lineEndConvention: #cr

There are 3 ways a field can be written (in increasing order of efficiency):

- quoted - converting it with #asString and quoting it (the default)
- raw - converting it with #asString but not quoting it
- object - not quoting it and using #printOn: directly on the output stream 

Obviously, when disabling qouting, you have to be sure your values do not contain embedded separators or line endings.
If you are writing arrays of numbers for example, this would be the fastest way to do it:

    neoCSVWriter
      fieldWriter: #object;
      nextPutAll: #( (100 200 300) (400 500 600) (700 800 900) )

The fieldWriter option applies to all fields.

If your data is in the form of regular domain level objects it would be wasteful 
to convert them to arrays just for writing them as CSV.
NeoCSV has a non-intrusive option to map your domain object''s fields.
You add field specifications based on accessors.
This is how you would write an array of Points.

    neoCSVWriter
      nextPut: #(x y);
      addFields: #(x y);
      nextPutAll: { 1@2. 3@4. 5@6 }

Note how we first write the header (before customizing the writer).
The addField: and addFields: methods arrange for the specified accessors 
to be performed on the incoming objects to produce values that will be written by the fieldWriter.
Additionally, there is protocol to specify different field writing behavior per field,
using addQuotedField:, addRawField: and addObjectField:.
To specify different field writers for an array (actually an SequenceableCollection subclass), 
you can use the methods first, second, third, ... as accessors.


## Customizing NeoCSVReader


The parser is flexible and forgiving.
Any line ending will do, quoted and non-quoted fields are allowed. 

Any character can be used as field separator, for example:

    neoCSVReader separator: Character tab

or

    neoCSVReader separator: $;

NeoCSVReader will produce records that are instances of its recordClass, which defaults to Array.
All fields are always read as Strings.
If you want, you can specify converters for each field, to convert them to integers or floats,
any other object. Here is an example:

    neoCSVReader
      addIntegerField;
      addFloatField;
      addField;
      addFieldConverter: [ :string | Date fromString: string ];
      upToEnd.

Here we specify 4 fields: an integer, a float, a string and a date field.
Field convertions specified this way only work on indexable record classes, like Array.

In many cases you will probably want your data to be returned as one of your domain objects.
It would be wasteful to first create arrays and then convert all those.
NeoCSV has non-intrusive options to create instances of your own object classes and 
to convert and set fields on them directly.
This is done by specifying accessors and converters.
Here is an example for reading Associations of Floats.

    (NeoCSVReader on: ''1.5,2.2\4.5,6\7.8,9.1'' withCRs readStream)
      recordClass: Association;
      addFloatField: #key: ;
      addFloatField: #value: ; 
      upToEnd.

For each field you give the mutator accessor to use, as well as an implicit or explicit conversion block.

One thing that it will enforce is that all records have an equal number of fields.
When there are no field accessors or converters, the field count will be set automatically after the first record is read.
If you want you could set it upfront.
When there are field accessors or converters, the field count will be set to the number of specified fields.'
]

{ #category : #documentation }
PharoTutorialCommonPackages class >> neoCSVTutorial2 [

	^'# More Infos

## How to load it

In Pharo 2.0 just open the configuration browser from the world menu
and load the package "NeoCSV".


## Web links

Here are some relevant links:

- <http://forum.world.st/ANN-NeoCSV-td4636208.html>
- <http://mc.stfx.eu/Neo/> 
'
]

{ #category : #documentation }
PharoTutorialCommonPackages class >> neoJSONTutorial1 [

	^'# JSON

*Sven Van Caekenberghe*

*June 2012*

*(This is a draft)*


JSON (JavaScript Object Notation) is a popular data-interchange format.
NeoJSON is an elegant and efficient standalone Smalltalk framework to 
read and write JSON converting to or from Smalltalk objects.   


## An introduction to JSON


JSON is a lightweight text-based open standard designed for human-readable data interchange. 
It was derived from the JavaScript scripting language for representing simple data structures and associative arrays, called objects. 
Despite its relationship to JavaScript, it is language-independent, with parsers available for many languages.

Here are some relevant links:

- <http://www.json.org/>
- <http://en.wikipedia.org/wiki/Json>
- <http://www.ietf.org/rfc/rfc4627.txt?number=4627>

There are only a couple of primitive types in JSON:

- numbers (integer or floating point)
- strings
- the boolean constants true and false
- null

Only two composite types exist:

- lists (an ordered sequenece of values)
- maps (an unordered associative array, mapping string property names to values)

That is really all there is to it. No options or additions are defined in the standard.


## NeoJSON


The NeoJSON framework contains a reader (NeoJSONReader) and a writer (NeoJSONWriter)
to parse respectively generate JSON to or from Smalltalk objects.
The goals of this project are:

- to be standalone (have no dependencies and have little requirements)
- to be small, elegant and understandable
- to be efficient (both in time and space)
- to be flexible and non-intrusive

Compared to other Smalltalk JSON frameworks, NeoJSON has

- less dependencies and little requirements
- can be more efficient (be faster and use less memory)
- allows for the use of schemas and mappings


## Primitives

Obviously, the primitive types are mapped to corresponding Smalltalk classes.
While reading:

- numbers become Integers or Floats
- strings become Strings
- booleans become Booleans
- null become nil

While writing

- Numbers are converted to floats, except for Integers that become integers
- Strings and subclasses become strings
- Booleans become booleans
- nil becomes null


## Generic Mode


NeoJSON can operate in a generic mode that requires no further configuration.
While reading:

- maps become instances of mapClass, Dictionary by default
- lists become instance of listClass, Array by default

The reader can be customized to use a different mapClass or listClass.
There is also an option to convert all map keys to symbols, which is off by default.
While writing:

- Dictionary and SmallDictionary become maps
- all other Collection classes become lists
- all other Objects are rejected

Here are some examples writing in generic mode:

	NeoJSONWriter toString: #(1 2 3).
	
	NeoJSONWriter toString: { Float pi. true. false. ''string'' }.
	
	NeoJSONWriter toStringPretty: (Dictionary new at: #x put: 1; at: #y put: 2; yourself).

NeoJSONWriter can output either in a compact format (the default) or in a pretty printed format.
And these are some examples reading in generic mode:

	NeoJSONReader fromString: '' [ 1,2,3 ] ''.

	NeoJSONReader fromString: '' [ 3.14159, true, false, null, "string" ] ''.

	NeoJSONReader fromString: '' { "x" : 1, "y" : 2 } ''.


In order to use the generic mode, you have to convert your domain objects to and from
Dictionaries and SequenceableCollections. This is realatively easy but not very efficient,
depending on the use case.


## Schemas and Mappings


NeoJSON allows for the optional specification of schemas and mappings to be used
when writing and/or when reading.
A NeoJSONMapper holds a number of schemas.
Each schema is identified by either a class or a symbol.
Each schema specifies a mapping, an object that will help in doing the actual reading or writing.

The most common mapping deals with objects that define a number of named properties or attributes.
These can be defined based on instance variables (optionally derived by reflection), 
accessors (getter/setter pairs) or even blocks.
Such an object mapping is identified by a Smalltalk class, which is also used to create new instances.
Each property mapping can have an optional value schema to be used recursively
when reading and/or writing property values.

The less common custom mapping holds a generic reader and/or writer block to deal with 
special cases such as specific collection types with an optional schema for the elements, 
or a direct mapping of semi primitive types such as Date or DateAndTime.

A mapping can be specified explicitely on a mapper, or can be resolved using the #neoJsonMapping: class method.

Here are some examples of mappings:

	mapper mapAllInstVarsFor: Point.

	mapper for: TestObject do: [ :mapping |
		mapping mapInstVars: #(id name).
		(mapping mapInstVar: #timestamp to: ''created-at'') valueSchema: DateAndTime.
		(mapping mapInstVar: #points) valueSchema: #ArrayOfPoints.
		(mapping mapInstVar: #bytes) valueSchema: ByteArray ].

	mapper for: DateAndTime customDo: [ :mapping |
		mapping decoder: [ :string | DateAndTime fromString: string ].
		mapping encoder: [ :dateAndTime | dateAndTime printString ] ].

	mapper for: #ArrayOfPoints customDo: [ :mapping |
		mapping listOfElementSchema: Point ].  

	mapper for: ByteArray customDo: [ :mapping |
		mapping listOfType: ByteArray ]

The classes NeoJSONReader and NeoJSONWriter are subclasses of NeoJSONMapper.
When writing, mappings are used when arbitrary objects are seen.
For example, in order to be able to write an array of points, you could do as follows:

	String streamContents: [ :stream |
		(NeoJSONWriter on: stream)
			prettyPrint: true;
			mapInstVarsFor: Point;
			nextPut: (Array with: 1@3 with: -1@3) ].

Collections are handled automatically, like in the generic case.
When reading, a mapping is used as a binding or an explicit type specifying what Smalltalk objects that you want to read.
Here is a very simple case, reading a map as a point:

	(NeoJSONReader on: '' { "x" : 1, "y" : 2 } '' readStream)
		mapInstVarsFor: Point;
		nextAs: Point.	

Since JSON lacks a universal way to specify the class of an object/map, 
we have to specify the target schema that we want to use as an argument to #nextAs:.
Finally, here is a more complex example, reading a list of maps as an array of points:

	(NeoJSONReader on: ''[ { "x" : 1, "y" : 2 }, { "x" : 3, "y" : 4 } ]'' readStream)
		mapInstVarsFor: Point;
		for: #ArrayOfPoints customDo: [ :mapping |
			mapping listOfElementSchema: Point ];
		nextAs: #ArrayOfPoints.

NeoJSON deals efficiently with mappings: the minimal amount of intermediary structures are created,
which is quite different from the generic case.


## Internals


On modern hardware, NeoJSON can write or read in the tens of thousands of small objects per second.
Several benchmarks are included in the unit tests package.'
]

{ #category : #documentation }
PharoTutorialCommonPackages class >> neoJSONTutorial2 [

	^'# More Infos

## How to load it

In Pharo 2.0 just open the configuration browser from the world menu
and load the package "NeoJSON".


## Web links

Here are some relevant links:

- <http://forum.world.st/ANN-NeoJSON-td4636209.html>
- <http://mc.stfx.eu/Neo/> 
'
]

{ #category : #tutorials }
PharoTutorialCommonPackages class >> packagesTutorialOn: aBuilder [
	<onlineTutorial>
	
	(aBuilder tutorial: #'Pharo packages')		 
		description: 'A short overview of interesting pharo projects and packages.';
		addLesson:  ((aBuilder lesson: #'Athens')						 
						description: 'Athens is a vector graphics package for Pharo.';
						addPage: #athensTutorial1 from: self;
						addPage: #athensTutorial2 from: self);
		addLesson:  ((aBuilder lesson: #'NeoCSV')						 
						description: 'A short overview of NeoCSV - a library to handle data in comma separated value format.';
						addPage: #neoCSVTutorial1 from: self;
						addPage: #neoCSVTutorial2 from: self);
		addLesson:  ((aBuilder lesson: #'NeoJSON')						 
						description: 'A short overview of NeoJSON - a library to handle data in JavaScript Object notation format.';
						addPage: #neoJSONTutorial1 from: self;
						addPage: #neoJSONTutorial2 from: self)				
]
