Class {
	#name : #OHTutorialRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'request handling' }
OHTutorialRequestHandler >> generateTutorialPage [
	 ^self helpPageWithContent: [:stream |		
		stream << self helpNavigationMenu.		
		stream << ' <div class="container" style="padding-top: 80px;">	
			<div id="contents" />EMPTY</div></div>
			<script type="text/javascript">
			 var converter1 = new Markdown.Converter();
                   var result = converter1.makeHtml("'.
	self markdown string linesDo: [:each | 
		stream << (each copyReplaceAll: '"' with: '\"').
		stream << '\n'
		].
		stream << '");		 	 	
			 document.getElementById("contents").innerHTML = result;
        </script>'
		
	]
]

{ #category : #'request handling' }
OHTutorialRequestHandler >> handleRequest: aRequest [
	| requestedClass action |
	requestedClass := (aRequest uri queryAt: 'class' ifAbsent: 'OHTutorialRequestHandler').
	requestedClass := (aRequest uri queryAt: 'class' ifAbsent: 'OHTutorialRequestHandler').	
	^self htmlResponse: self generateTutorialPage 
]

{ #category : #'request handling' }
OHTutorialRequestHandler >> markdown [
	^'A First Level Header
====================

A Second Level Header
---------------------

Now is the time for all good men to come to
the aid of their country. This is just a
regular paragraph.

The quick brown fox jumped over the lazy
dog''s back.

### Header 3

> This is a blockquote.
> 
> This is the second paragraph in the blockquote.
>
> ## This is an H2 in a blockquote
'

]

{ #category : #defaults }
OHTutorialRequestHandler >> prefix [
	^'tutorial'
]
