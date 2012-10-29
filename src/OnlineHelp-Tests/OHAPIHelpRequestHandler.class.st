"
This is an example of a request handler (here for the API help).


"
Class {
	#name : #OHAPIHelpRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core'
}

{ #category : #'request handling' }
OHAPIHelpRequestHandler >> handleRequest: aRequest [
 	
	| requestedClass |
	requestedClass := (aRequest uri queryAt: 'class' ifAbsent: 'Object').
 	^self htmlResponse: (self pageForClass: requestedClass).				
	 
]

{ #category : #'request handling' }
OHAPIHelpRequestHandler >> pageForClass: aClass [
	| realClass |
	realClass := Smalltalk at: aClass asSymbol.
	
	^self helpPageWithContent: [:stream |
		stream << '<h1>' << realClass name << '</h1>'.
		realClass subclasses do: [:each |
			stream << '<li><a href="reference?class='.
			stream << each name.
			stream <<  '">'.
			stream << each name.
			stream << '</a>'
		]	
	]
]

{ #category : #defaults }
OHAPIHelpRequestHandler >> prefix [
	^'api'
]
