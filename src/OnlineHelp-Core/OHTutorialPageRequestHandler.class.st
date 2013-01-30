Class {
	#name : #OHTutorialPageRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #private }
OHTutorialPageRequestHandler >> decodeAsLink: aString [
	"Decode the given string to URL style"
	
	^ZnResourceMetaUtils decodePercent: aString
]

{ #category : #private }
OHTutorialPageRequestHandler >> encodeFromLink: aString [
	"Encode the givenURL style string to name"
	
	^ZnResourceMetaUtils encodePercent: aString withEncoding: 'utf-8'
]

{ #category : #'rendering-common' }
OHTutorialPageRequestHandler >> generateAllTutorialsPage [
	 ^self helpPageWithContent: [:stream |		
		stream << self helpNavigationMenu.		
		stream << '<br/><div class="container" style="padding-top: 40px;">'.
		
			stream << '<div class="row">'.
				"left side navigation"
		 		stream << '<div class="span3">'.
					self renderTutorialSelectionOn: stream.
				stream << '</div>'.
				"right side"
		 		stream << '<div class="span9">'.
					self renderAvailableTutorialsOn: stream.
				stream << '</div>'.						
			stream << '</div>'.
		
		stream << '</div>']
]

{ #category : #'rendering-common' }
OHTutorialPageRequestHandler >> generatePageForLesson: aLesson tutorial: aTutorial [ 
	 ^self helpPageWithContent: [:stream |		
		stream << self helpNavigationMenu.		
		stream << '<br/><div class="container" style="padding-top: 40px;">'.
		
			stream << '<div class="row">'.
				"left side navigation"
		 		stream << '<div class="span3">'.
					self renderTutorialSelectionOn: stream.
				stream << '</div>'.
				"right side"
		 		stream << '<div class="span9">'.
					self renderLessonOverview: aLesson forTutorial: aTutorial on: stream.
				stream << '</div>'.						
			stream << '</div>'.
		
		stream << '</div>']
]

{ #category : #'rendering-common' }
OHTutorialPageRequestHandler >> generatePageForTutorial: aTutorial [
	 ^self helpPageWithContent: [:stream |		
		stream << self helpNavigationMenu.		
		stream << '<br/><div class="container" style="padding-top: 40px;">'.
		
			stream << '<div class="row">'.
				"left side navigation"
		 		stream << '<div class="span3">'.
					self renderTutorialSelectionOn: stream.
				stream << '</div>'.
				"right side"
		 		stream << '<div class="span9">'.
					self renderTutorialOverview: aTutorial on: stream.
				stream << '</div>'.						
			stream << '</div>'.
		
		stream << '</div>']
]

{ #category : #markdown }
OHTutorialPageRequestHandler >> generateTutorialPage [
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
OHTutorialPageRequestHandler >> handleRequest: aRequest [
	|  action tutorial lesson page |
 
	tutorial := aRequest uri queryAt: 'tutorial' 
							 ifAbsent: [ ^self htmlResponse: self generateAllTutorialsPage].						 
	lesson := aRequest uri queryAt: 'lesson' 
							 ifAbsent: [^self htmlResponse: (self generatePageForTutorial: tutorial asSymbol) ].	
	page := aRequest uri queryAt: 'page' 
							 ifAbsent: [^self htmlResponse: (self generatePageForLesson: lesson asSymbol tutorial: tutorial asSymbol) ].	
	^self htmlResponse: self generateTutorialPage 
]

{ #category : #markdown }
OHTutorialPageRequestHandler >> markdown [
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
OHTutorialPageRequestHandler >> prefix [
 
	^'tutorials'
]

{ #category : #'rendering-tutorials' }
OHTutorialPageRequestHandler >> renderAvailableTutorialsOn: stream [
	"Render the content menu for all tutorials"

	stream << '<ul class="breadcrumb">
					<li><a href="/tutorials">Home</a></li>  
			</ul>'.

	"Render all tutorials with description"
	self tutorialsToRender do: [ :tutorial |	 
 		stream << '<h3><a name="' << (self decodeAsLink: tutorial title) << '"></a>'.
		stream << '<a href="tutorials?tutorial=' << (self decodeAsLink: tutorial title) << '">' << tutorial title asString << '</a></h3>'.
		stream << '<h4 class="muted">&nbsp;&nbsp;' << tutorial description << '</h4>' ]
]

{ #category : #'rendering-common' }
OHTutorialPageRequestHandler >> renderLessonOverview: aLesson forTutorial: aTutorial on: stream [
	|tutorial lesson |
	tutorial := self tutorialNamed: aTutorial.
	lesson := tutorial lessonNamed: aLesson.
	
	stream << '<ul class="breadcrumb">
					<li><a href="/tutorials">Home</a><span class="divider">/</span></li>
					<li><a href="tutorials?tutorial=' << (self decodeAsLink: tutorial title) << '">' << tutorial title asString << '</a> <span class="divider">/</span></li>
					<li><a href="#">' << lesson title asString << '</a></li>
			</ul>'.
	
	 
]

{ #category : #'rendering-tutorials' }
OHTutorialPageRequestHandler >> renderTutorialOverview: aTutorial on: stream [
	|tutorial|
	tutorial := self tutorialNamed: aTutorial.	 
	 
	stream << '<ul class="breadcrumb">
					<li><a href="/tutorials">Home</a><span class="divider">/</span></li>
					<li><a href="#">' << tutorial title asString << '</a> <span class="divider">/</span></li>
			</ul>'.

	 
	tutorial lessons do: [:each |
		stream << '<h3>'.
		stream << '<a href="tutorials?tutorial=' << (self decodeAsLink: tutorial title) << '&lesson=' << (self decodeAsLink: each title) << '">' << (each title asString) << '</a></h3>'.
		stream << '</h3>'.
		stream << '<span>' << each description << '</span>' ]
		
	
]

{ #category : #'rendering-tutorials' }
OHTutorialPageRequestHandler >> renderTutorialSelectionOn: stream [
	"Render the sidebar navigation for all tutorials"
	
	stream << '<div class="sidebar-nav">
						<div class="well" style="padding: 8px 0;">
							<ul class="nav nav-list">
								<li class="nav-header">Home</li>
								<li><a href="/tutorials">All Tutorials</a></li>	
								<li class="nav-header">Tutorials</li>'.

	self tutorialsToRender do: [ :tutorial |
	 
		stream << '<li><a href="/tutorials#'.
		stream << (self decodeAsLink: tutorial title).
		stream <<  '">'.
		stream << tutorial title.
		stream << '</a></li>'].					
					
	stream << '</ul></div></div>'.


	
]

{ #category : #accessing }
OHTutorialPageRequestHandler >> tutorialNamed: aName [
	^OHTutorialBuilder tutorialWithName: aName
]

{ #category : #accessing }
OHTutorialPageRequestHandler >> tutorialsToRender [
	^OHTutorialBuilder availableTutorials
]
