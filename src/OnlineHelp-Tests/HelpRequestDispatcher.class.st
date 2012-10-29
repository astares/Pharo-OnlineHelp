Class {
	#name : #HelpRequestDispatcher,
	#superclass : #Object,
	#instVars : [
		'dispatchMap'
	],
	#category : #'OnlineHelp-Core'
}

{ #category : #building }
HelpRequestDispatcher >> buildDispatchMap [
 
	| handler |
	self				
		map: 'help' to: #help:;				
		map: '/' to: 'welcome';				
		map: 'favicon.ico' to: #favicon:.
		
	OHHelpRequestHandler allSubclassesDo: [:each |
		handler := each new.
		self map: handler prefix  to: handler
	]
]

{ #category : #accessing }
HelpRequestDispatcher >> dispatchMap [
	^ dispatchMap ifNil: [ dispatchMap := Dictionary new ]
]

{ #category : #'standard responses' }
HelpRequestDispatcher >> favicon: request [
	"Answer a nice favicon for browsers to display"

	| entity |
	entity := ZnEntity with: HelpResourceLibrary faviconBytes type: 'image/vnd.microsoft.icon'. 
	^ ZnResponse ok: entity
]

{ #category : #private }
HelpRequestDispatcher >> generateHelp [

	^ String streamContents: [ :stream |
		stream << ZnConstants standardHtmlDocType.
		stream << '<html><head><title>Pharo Help</title><link rel="shortcut icon" href="/favicon.ico"/>'.
		stream << '<style type="text/css"> '.
		stream << HelpResourceLibrary helpCss.
		stream << '</style>'.		
		stream << '</head>'.
		stream << '<body><h1>Pharo Help</h1><h3>Online Help</h3><ul>'.
		dispatchMap keys do: [ :each | 
			stream << '<li><a href="'; << each; << '">'; << each; << '</a></li>' ].
		stream << '<ul></body></html>' ]
]

{ #category : #dispatching }
HelpRequestDispatcher >> handleRequest: aRequest [
	| prefix prefixHandler |
	prefix := aRequest uri isSlash
		ifTrue: [ dispatchMap  at: '/' ifAbsent: [ nil ] ]
		ifFalse: [ aRequest uri firstPathSegment ].
	prefixHandler := dispatchMap at: prefix ifAbsent: [ nil ].
	prefixHandler isNil
		ifFalse: [ 
			^ prefixHandler isSymbol
				ifTrue: [ self perform: prefixHandler with: aRequest ]
				ifFalse: [ prefixHandler handleRequest: aRequest ] ].
	^ ZnResponse notFound: aRequest uri

]

{ #category : #responses }
HelpRequestDispatcher >> help: request [
	"Reply with a dynamic HTML page containing links to all pages I support"

	^ ZnResponse ok: (ZnEntity html: self generateHelp)
	
]

{ #category : #'initialize-release' }
HelpRequestDispatcher >> initialize [ 
	super initialize.
	self buildDispatchMap
]

{ #category : #accessing }
HelpRequestDispatcher >> map: prefix to: handler [
	"Arrange for the receiver to dispatch requests matching prefix to handler.
	Handler can be a symbol naming a method in the receiver, 
	or a block accepting the request and producing the response"
	
	self dispatchMap  
		at: prefix
		put: handler
		
]
