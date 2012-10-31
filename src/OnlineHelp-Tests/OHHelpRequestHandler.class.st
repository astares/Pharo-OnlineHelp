Class {
	#name : #OHHelpRequestHandler,
	#superclass : #Object,
	#category : #'OnlineHelp-Core'
}

{ #category : #'request handling' }
OHHelpRequestHandler >> handleRequest: aRequest [
	| entity |
	entity := ZnEntity text: 'Request handler method in ',self class name,' has to be implemented'.
	^ ZnResponse ok: entity

]

{ #category : #private }
OHHelpRequestHandler >> helpPageWithContent: aBlock [

	^ String streamContents: [ :stream |
		stream << ZnConstants standardHtmlDocType.
		stream << '<html><head><title>Pharo Help</title><link rel="shortcut icon" href="/favicon.ico"/>'.
		stream << '<link rel="stylesheet" type="text/css" href="/files/css/bootstrap.min.css">'.	
		stream <<	'
			<script src="http://bootsnipp.com/bundles/bootstrapper/js/jquery-1.8.1.min.js"></script>
			<script src="http://bootsnipp.com/bundles/bootstrapper/js/bootstrap.min.js"></script>'.
		stream << '<style type="text/css"> '.
		stream << HelpResourceLibrary helpCss.	
		stream << '</style></head><body>'.
		aBlock value: stream.
		stream << '</body></html>' ]

	
]

{ #category : #private }
OHHelpRequestHandler >> htmlResponse: html [
	"Reply with a dynamic HTML page"

	^ ZnResponse ok: (ZnEntity html:  html)
]

{ #category : #defaults }
OHHelpRequestHandler >> prefix [
	^self subclassResponsibility 
]

{ #category : #private }
OHHelpRequestHandler >> respondWith: content usingMIMEType: mimeType [ 
	| entity |
	entity := ZnEntity with: content type: mimeType. 
	^ ZnResponse ok: entity
]
