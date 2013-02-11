Class {
	#name : #OHIntroRequestHandler,
	#superclass : #OHHelpRequestHandlerOld,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'request handling' }
OHIntroRequestHandler >> generateAllTutorialsPage [
	 ^self helpPageWithContent: [:stream |		
		stream << self helpNavigationMenu.		
		stream << '<br/><div class="container" style="padding-top: 40px;">'.
		
			stream << '<div class="row">'.
				"left side navigation"
		 		stream << '<div class="span3">'.
					self renderAvailableTutorialsOn: stream.
				stream << '</div>'.
				"right side"
		 		stream << '<div class="span9">'.
					self renderAvailableTutorialsAndLessonsOn: stream.
				stream << '</div>'.						
			stream << '</div>'.
		
		stream << '</div>']
]

{ #category : #obsolete }
OHIntroRequestHandler >> generateLessonPage [
	 ^self helpPageWithContent: [:stream |		
		stream << self helpNavigationMenu.		
		stream << '<br/><div class="container" style="padding-top: 40px;">'.
		
			stream << '<div class="row">'.
				"left side navigation"
		 		stream << '<div class="span3">'.
					self renderAvailableTutorialsOn: stream.
				stream << '</div>'.
				"right side"
		 		stream << '<div class="span9">'.
					self renderAvailableTutorialsAndLessonsOn: stream.
				stream << '</div>'.						
			stream << '</div>'.
		
		stream << '</div>']
]

{ #category : #obsolete }
OHIntroRequestHandler >> generateLessonPage2 [
	 ^self helpPageWithContent: [:stream |		
		stream << self helpNavigationMenu.		
		stream << '		 
 		<br/>
		<div class="container" style="padding-top: 40px;">			 
            		<h1>Introduction</h1>
            		 <div class="row">
					<div class="span7">
     				      	<h4><a href="#">Lesson 1</a></h4>
				      	<p>Overview of the Pharo environment and the tools. You will learn how to use the Pharo environment.</p>
					</div>  					
		   		</div>
				<hr>
				<div class="row">
					<div class="span7">
     				      	<h4><a href="#">Lesson 2</a></h4>
				      	<p>An introduction into the Smalltalk programming language.</p>
					</div>  					
		   		</div>				
		</div>']
]

{ #category : #obsolete }
OHIntroRequestHandler >> generateLessonPage3 [
	 ^self helpPageWithContent: [:stream |		
		stream << self helpNavigationMenu.		
		stream << '<br/><div class="container" style="padding-top: 40px;">'.
		
			stream << '<div class="row">'.
				"left side navigation"
		 		stream << '<div class="span3">'.
					self renderAvailableTutorialsOn: stream.
				stream << '</div>'.
				"right side"
		 		stream << '<div class="span9">'.
					self renderAvailableTutorialsAndLessonsOn: stream.
				stream << '</div>'.						
			stream << '</div>'.
		
		stream << '</div>']
]

{ #category : #'request handling' }
OHIntroRequestHandler >> handleRequest: aRequest [
	^self htmlResponse: self generateAllTutorialsPage 
]

{ #category : #defaults }
OHIntroRequestHandler >> prefix [
	^'oldintro'
]

{ #category : #'request handling' }
OHIntroRequestHandler >> renderAvailableTutorialsAndLessonsOn: stream [

	self tutorialsToRender do: [ :tutorial |	 
 		stream << '<h3><a name="' << (ZnResourceMetaUtils decodePercent: tutorial title).
		stream << '"></a>' << tutorial title << '</h3>'.
		stream << '<h4 class="muted">' << tutorial description << '</h4>'.
		tutorial lessons do: [:lesson | 
			self renderLesson: lesson fromTutorial: tutorial on: stream ]]
]

{ #category : #'request handling' }
OHIntroRequestHandler >> renderAvailableTutorialsOn: stream [

	stream << '<div class="sidebar-nav">
						<div class="well" style="padding: 8px 0;">
							<ul class="nav nav-list">
								<li class="nav-header">Tutorials</li>'.

	self tutorialsToRender do: [ :tutorial |
	 
		stream << '<li><a href="#'.
		stream << (ZnResourceMetaUtils decodePercent: tutorial title).
		stream <<  '">'.
		stream << tutorial title.
		stream << '</a></li>'].					
					
	stream << '</ul>
				</div>			
			 </div>'.


	
]

{ #category : #'request handling' }
OHIntroRequestHandler >> renderLesson: lesson fromTutorial: tutorial on: stream [ 

	stream << '<li>'.
	stream << lesson title.
]

{ #category : #'request handling' }
OHIntroRequestHandler >> tutorialsToRender [
	^OHTutorialBuilder availableTutorials
]
