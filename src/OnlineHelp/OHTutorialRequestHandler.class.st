Class {
	#name : #OHTutorialRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Web'
}

{ #category : #private }
OHTutorialRequestHandler >> decodeAsLink: aString [
	"Decode the given string to URL style"
	
	^ZnResourceMetaUtils decodePercent: aString
]

{ #category : #'rendering-pages' }
OHTutorialRequestHandler >> linkToPageNr: page using: aContext content: aString [
	|stream|
	stream := aContext responseStream.
	stream << '<li><a href="/tutorials?tutorial='.
	stream << aContext request tutorial.
	stream << '&lesson='.
	stream << aContext request lesson.
	stream << '&page='.
	stream << page.
	stream << '">'.
	stream << aString.
	stream << '</a></li>'
	 

]

{ #category : #'rendering-pages' }
OHTutorialRequestHandler >> markdown: aString on: stream [

	stream << '<div class="container span9">	
			<div id="contents" />EMPTY</div></div>
			<script type="text/javascript">
			 var converter1 = new Markdown.Converter();
                   var result = converter1.makeHtml("'.
	aString linesDo: [:each | 
		stream << (each copyReplaceAll: '"' with: '\"').
		stream << '\n'
		].
		stream << '");		 	 	
			 document.getElementById("contents").innerHTML = result;
        </script>
'
		
	 
]

{ #category : #defaults }
OHTutorialRequestHandler >> prefix [
	"Return the prefix for tutorials"
	
	^'tutorials'
]

{ #category : #'rendering-tutorials' }
OHTutorialRequestHandler >> renderAllTutorialsOn: stream [

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
		
		stream << '</div>'
]

{ #category : #'rendering-tutorials' }
OHTutorialRequestHandler >> renderAvailableTutorialsOn: stream [
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

{ #category : #rendering }
OHTutorialRequestHandler >> renderContentUsing: aContext [
 
	aContext request hasTutorial ifFalse: [ ^self renderAllTutorialsOn: aContext responseStream ].
	aContext request hasLesson ifFalse: [ ^self renderTutorialUsing: aContext ].
	aContext request hasPage ifFalse: [ ^self renderLessonUsing: aContext ].
	^self renderPageUsing: aContext 
]

{ #category : #'rendering-lessons' }
OHTutorialRequestHandler >> renderLessonOverviewUsing: aContext [ 

	|tutorial lesson |
 
	tutorial := self tutorialNamed: aContext request tutorial.
	lesson := tutorial lessonNamed: aContext request lesson asSymbol.
	
	aContext responseStream  << '<ul class="breadcrumb">
					<li><a href="/tutorials">Home</a><span class="divider">/</span></li>
					<li><a href="tutorials?tutorial=' << (self decodeAsLink: tutorial title) << '">' << tutorial title asString << '</a> <span class="divider">/</span></li>
					<li><a href="#">' << lesson title asString << '</a></li>
			</ul>'.
	
	 self renderPage: 1 using: aContext
]

{ #category : #'rendering-lessons' }
OHTutorialRequestHandler >> renderLessonUsing: aContext [ 
	| stream |
	stream := aContext responseStream. 
	stream << '<br/><div class="container" style="padding-top: 40px;">'.		
		stream << '<div class="row">'.
			"left side navigation"
	 		stream << '<div class="span3">'.
				self renderTutorialSelectionOn: stream.
			stream << '</div>'.
			"right side"		
			stream << '<div class="span9">'.
				self renderLessonOverviewUsing: aContext.
			stream << '</div>'.						
	stream << '</div>'.
]

{ #category : #'rendering-pages' }
OHTutorialRequestHandler >> renderPage: pageNumber using: aContext [

	|tutorial lesson content stream |
	tutorial := self tutorialNamed: aContext request tutorial.
	lesson := tutorial lessonNamed: aContext request lesson asSymbol.
 
	content := lesson contentForPage: aContext request page asInteger.
	stream := aContext responseStream.
	stream << '<div class="pagination .pagination-mini"><ul>'.

	"Pagination"
	self linkToPageNr: 1 using: aContext content: '&lt;&lt;'.
	1 to: lesson numberOfPages do: [: page | self linkToPageNr: page using: aContext content: page asString ].
	self linkToPageNr: lesson numberOfPages using: aContext content: '&gt;&gt;'.

	stream << '</ul></div>'.
	
	self markdown: content on: stream.

	"Also add the websequence diagram script"	
	stream << '<script type="text/javascript" src="http://www.websequencediagrams.com/service.js"></script>'
	
]

{ #category : #'rendering-pages' }
OHTutorialRequestHandler >> renderPageUsing: aContext [ 
	|stream|
	stream :=aContext responseStream.
	stream << '<br/><div class="container" style="padding-top: 40px;">'.
		
			stream << '<div class="row">'.
				"left side navigation"
		 		stream << '<div class="span3">'.
					self renderTutorialSelectionOn: stream.
				stream << '</div>'.
				"right side"
		 		stream << '<div class="span9">'.
					self renderLessonOverviewUsing: aContext.
				 					 
				stream << '</div>'.						
			stream << '</div>'.
		
		stream << '</div>'
]

{ #category : #'rendering-tutorials' }
OHTutorialRequestHandler >> renderTutorialOverviewUsing: aContext [

	|tutorial stream |
	tutorial := self tutorialNamed: aContext request tutorial.	 
	stream := aContext responseStream.
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
OHTutorialRequestHandler >> renderTutorialSelectionOn: stream [
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

{ #category : #'rendering-tutorials' }
OHTutorialRequestHandler >> renderTutorialUsing: aContext [  

	| stream aTutorial |
	stream := aContext responseStream.
	stream << '<br/><div class="container" style="padding-top: 40px;">'.		
	stream << '<div class="row">'.
		"left side navigation"
		stream << '<div class="span3">'.
			self renderTutorialSelectionOn: stream.
		stream << '</div>'.
		"right side"
		stream << '<div class="span9">'.
			self renderTutorialOverviewUsing: aContext.
		stream << '</div>'.						
	stream << '</div>'.
]

{ #category : #defaults }
OHTutorialRequestHandler >> requestClass [
	^OHTutorialRequest 
]

{ #category : #accessing }
OHTutorialRequestHandler >> tutorialNamed: aName [
	^OHTutorialBuilder tutorialWithName: aName
]

{ #category : #accessing }
OHTutorialRequestHandler >> tutorialsToRender [
	^OHTutorialBuilder availableTutorials
]
