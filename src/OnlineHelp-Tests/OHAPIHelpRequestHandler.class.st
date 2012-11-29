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
 	
	| requestedClass action |
	action := (aRequest uri queryAt: 'action' ifAbsent: 'comment').
	requestedClass := (aRequest uri queryAt: 'class' ifAbsent: 'Object').
 	^self htmlResponse: (self renderPageForClass: requestedClass action: action).				
	 
]

{ #category : #defaults }
OHAPIHelpRequestHandler >> prefix [
	^'api'
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderAction: anAction for: aClass on: stream [

	anAction = 'comment' ifTrue: [ self renderCommentFor: aClass on: stream].
	anAction = 'instance' ifTrue: [ self renderInstanceSideFor: aClass on: stream].
	
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderActionNavigationFor: realClass onStream: stream action: anAction [
	|actions|
	actions := { 'comment'-> 'Comment'. 'instance'-> 'Instance'.  'class'-> 'Class'}.

	stream << '
		<div class="navbar">
              <div class="navbar-inner">                
                <ul class="nav">'.
	
	actions do: [:each | 
		each key = anAction 
			ifTrue: [ stream << '<li class="active">' ]
			ifFalse: [ stream << '<li>' ].
		
		stream << '<a href="api?action='.
		stream << each key.
		stream << '&class='.
		stream << realClass name.
		stream <<'">'.
		stream << each value.
		stream << '</a></li>'.
	].
      
	stream << '
		    </ul>
             </div>
           </div>'.
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderCommentFor: aClass on: stream [
	stream << '<pre>'.
	stream << aClass comment.
	stream << '</pre>'.
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderInstanceSideFor: aClass on: stream [

	stream << '<div class="accordion">'.
	stream << '<div class="accordion-group">'.
	aClass methods do: [:each |
		self renderMethod: each on: stream.	
	
	 ].
              
	
	stream << '</div>'.
	stream << '</div>'.
		
               
             
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderMethod: each on: stream [

 	|selector|
	selector := each selector asString copyReplaceAll: ':' with: ''.
 	stream << '<div class="accordion-heading">'.
		stream << '<a class="accordion-toggle" data-toggle="collapse" href="#' << selector << '">'.
		stream << each selector asString.
		stream << '</a>'.
	stream << '</div>'.
	stream << ' 
                  <div id="' << selector << '" class="accordion-body collapse ">
                    <div class="accordion-inner">
                      Anim pariatur cliche reprehenderit, enim eiusmod high life accusamus terry richardson ad squid. 3 wolf moon officia aute, non cupidatat skateboard dolor brunch. Food truck quinoa nesciunt laborum eiusmod. Brunch 3 wolf moon tempor, sunt aliqua put a bird on it squid single-origin coffee nulla assumenda shoreditch et. Nihil anim keffiyeh helvetica, craft beer labore wes anderson cred nesciunt sapiente ea proident. Ad vegan excepteur butcher vice lomo. Leggings occaecat craft beer farm-to-table, raw denim aesthetic synth nesciunt you probably h heard of them accusamus labore sustainable VHS.
                    </div>
                  </div>
	'.
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderNavigationFor: realClass onStream: stream action: anAction [
		
	stream << '<div class="sidebar-nav">
						<div class="well" style="padding: 8px 0;">
							<ul class="nav nav-list">'.
				"write superclass if available"
				realClass superclass notNil ifTrue: [
					stream << '<li class="nav-header">Superclass</li>'.
					self writeLinkTo: realClass superclass on: stream action: anAction ].	

				"write subclasses if available"			 
				realClass subclasses notEmpty ifTrue: [
					stream << '<li class="nav-header">Subclasses</li>'.				
					realClass subclasses do: [:each | self writeLinkTo: each on: stream action: anAction ]].		
				        
		stream << '</ul>
				</div>			
			 </div>'.
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderPageForClass: aClass action: anAction [
	| realClass |
	realClass := Smalltalk at: aClass asSymbol.
 
	^self helpPageWithContent: [:stream |
		stream << self helpNavigationMenu.
		stream << '
		<br/>
		<div class="container" style="padding-top: 40px;">'.
		stream << '<div class="page-header">'.
			stream << '<h1>' << realClass name << '</h1>'.
          	stream << '</div>'.

		self renderActionNavigationFor: realClass onStream: stream action: anAction.
		
		
		stream << '<div class="row">'.
			"left side navigation"
		 	stream << '<div class="span3">'.
				self renderNavigationFor: realClass onStream: stream action: anAction.
			stream << '</div>'.
			"right side"
		 	stream << '<div class="span9">'.
				self renderAction: anAction for: realClass on: stream.
			stream << '</div>'.						
		stream << '</div>'.
			
	]
]

{ #category : #private }
OHAPIHelpRequestHandler >> writeLinkTo: class on: stream action: action [
	stream << '<li><a href="api?action='.
	stream << action.
	stream << '&class='.
	stream << class name.
	stream <<  '">'.
	stream << class name.
	stream << '</a></li>'
]
