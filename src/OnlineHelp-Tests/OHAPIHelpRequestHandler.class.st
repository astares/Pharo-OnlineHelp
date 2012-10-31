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
		stream << self helpNavigationMenu.
		stream << '
		<br/>
		<div class="container" style="padding-top: 40px;">'.
		stream << '<h1>' << realClass name << '</h1>'.
		stream << '<div class="sidebar-nav">
						<div class="well" style="width:300px; padding: 8px 0;">
							<ul class="nav nav-list">'.
		"write superclass if available"
		realClass superclass notNil ifTrue: [
			stream << '<li class="nav-header">Superclass</li>'.
			self writeLinkTo: realClass superclass on: stream.
		].	

		"write subclasses if available"			 
		realClass subclasses notEmpty ifTrue: [
			stream << '<li class="nav-header">Subclasses</li>'.				
			realClass subclasses do: [:each | self writeLinkTo: each on: stream ]].		
				        
		stream << '
			   </ul>
			</div>
		   </div>
		</div>'	
	]
]

{ #category : #defaults }
OHAPIHelpRequestHandler >> prefix [
	^'api'
]

{ #category : #private }
OHAPIHelpRequestHandler >> writeLinkTo: class on: stream [
	stream << '<li><a href="api?class='.
	stream << class name.
	stream <<  '">'.
	stream << class name.
	stream << '</a>'
]
