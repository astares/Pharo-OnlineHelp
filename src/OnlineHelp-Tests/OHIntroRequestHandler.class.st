Class {
	#name : #OHIntroRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core'
}

{ #category : #'request handling' }
OHIntroRequestHandler >> generateLessonPage [
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
