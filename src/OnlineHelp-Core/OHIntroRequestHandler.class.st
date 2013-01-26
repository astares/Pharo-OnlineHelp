Class {
	#name : #OHIntroRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #'request handling' }
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

{ #category : #'request handling' }
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

{ #category : #'request handling' }
OHIntroRequestHandler >> handleRequest: aRequest [
	^self htmlResponse: self generateLessonPage 
]

{ #category : #defaults }
OHIntroRequestHandler >> prefix [
	^'intro'
]

{ #category : #'request handling' }
OHIntroRequestHandler >> renderAvailableTutorialsAndLessonsOn: stream [

	self tutorialsToRender do: [ :tutorial |
 		stream << '<h2>' << tutorial title << '</h2>'.
		stream << '<h3 class="muted">' << tutorial description << '</h3><br/>']
]

{ #category : #'request handling' }
OHIntroRequestHandler >> renderAvailableTutorialsOn: stream [

	stream << '<div class="sidebar-nav">
						<div class="well" style="padding: 8px 0;">
							<ul class="nav nav-list">
								<li class="nav-header">Tutorials</li>'.

	self tutorialsToRender do: [ :tutorial |
		
		stream << '<li><a href="#'.
		stream << tutorial title.
		stream <<  '">'.
		stream << tutorial title.
		stream << '</a></li>'
	
	 ].					
					
	stream << '</ul>
				</div>			
			 </div>'.


	
]

{ #category : #accessing }
OHIntroRequestHandler >> tutorialsToRender [
	^OHTutorialBuilder availableTutorials
]
