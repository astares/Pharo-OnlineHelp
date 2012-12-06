Class {
	#name : #OHTutorialRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core'
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
	^self htmlResponse: self generateTutorialPage 
]

{ #category : #'request handling' }
OHTutorialRequestHandler >> markdown [
	^'#Pharo Tutorial 
##Lesson 2
### Lesson 3

"Hellos "


'

]

{ #category : #defaults }
OHTutorialRequestHandler >> prefix [
	^'tutorial'
]
