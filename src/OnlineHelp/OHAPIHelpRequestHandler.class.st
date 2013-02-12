Class {
	#name : #OHAPIHelpRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Web'
}

{ #category : #defaults }
OHAPIHelpRequestHandler >> prefix [
	"Return the prefix for tutorials"
	
	^'api'
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderActionNavigationUsing: aContext [

	|actions stream|
	stream := aContext responseStream.
	actions := { 'comment'-> 'Comment'. 'instance'-> 'Instance'.  'class'-> 'Class'}.

	stream << '
		<div class="navbar">
              <div class="navbar-inner">                
                <ul class="nav">'.
	
	actions do: [:each | 
		each key = aContext request action 
			ifTrue: [ stream << '<li class="active">' ]
			ifFalse: [ stream << '<li>' ].
		
		stream << '<a href="api?action=' 
		 		<< each key
		            << '&item='
		            << aContext request itemAsRealClass name.
		stream <<'">'
		           << each value
			     << '</a></li>' ].
		
	stream << '
		    </ul>
             </div>
           </div>'.
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderActionUsing: aContext [ 

	aContext request action = 'comment' ifTrue: [ ^self renderCommentUsing: aContext ].
	aContext request action = 'instance' ifTrue: [ ^self renderInstanceSideUsing: aContext ].
	aContext request action = 'class' ifTrue: [ ^self renderClassSideUsing: aContext ].
	
	 
]

{ #category : #'rendering-class' }
OHAPIHelpRequestHandler >> renderClassSideUsing: aContext [  

	self renderMethods: aContext request itemAsRealClass class methods on: aContext responseStream 
]

{ #category : #'rendering-class' }
OHAPIHelpRequestHandler >> renderCommentUsing: aContext [

	aContext responseStream << '<pre>'.
	aContext responseStream << aContext request itemAsRealClass comment.
	aContext responseStream << '</pre>'.
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderContentUsing: aContext [ 
	
	| stream |
	stream :=aContext responseStream.
	stream << '<br/>'
		      << '<div class="container" style="padding-top: 40px;">' 
			<< '     <div class="page-header">' 
			<< '         <h1>' << aContext request itemAsRealClass name << '</h1>' 
      		<< '     </div>'.
	
	self renderActionNavigationUsing: aContext.
	
	    stream << '<div class="row">'.

	        "left side navigation"
	        stream << '<div class="span3">'.
	        	self renderNavigationUsing: aContext.
	        stream << '</div>'.
	
		"right side"
		stream << '<div class="span9">'.
			self renderActionUsing: aContext.
		stream << '</div>'.		
			 				
  	    stream << '</div>' 
		<< '</div>'.
]

{ #category : #'rendering-class' }
OHAPIHelpRequestHandler >> renderInstanceSideUsing: aContext [  

	self renderMethods: aContext request itemAsRealClass methods on: aContext responseStream 
]

{ #category : #'rendering-class' }
OHAPIHelpRequestHandler >> renderMethod: each on: stream [

 	|selector|
	selector := each selector asString copyReplaceAll: ':' with: 'P'.
 	stream << '<div class="accordion-heading">'.
		stream << '<a class="accordion-toggle" data-toggle="collapse" href="#' << selector << '">'.
		stream << each selector asString.
		stream << '</a>'.
	stream << '</div>'.
	stream << ' 
                  <div id="' << selector << '" class="accordion-body collapse ">
                    <div class="accordion-inner"><pre>'.
	each comment isNil 
		ifTrue: [ stream << ' - UNCOMMENTED - ']
		ifFalse: [ stream << each comment ].	
   	stream << '                    </pre>
                    </div>
                  </div>
	'.
]

{ #category : #'rendering-class' }
OHAPIHelpRequestHandler >> renderMethods: methods on: stream [
 
	stream << '<div class="accordion">'.
	stream << '<div class="accordion-group">'.
	(methods sort: [:a :b | a selector asString < b selector asString ]) do: [:each |
		self renderMethod: each on: stream ].
	stream << '</div>'.
	stream << '</div>'.
		
               
             
]

{ #category : #rendering }
OHAPIHelpRequestHandler >> renderNavigationUsing: aContext [ 
	|realClass stream action |
	realClass := aContext request itemAsRealClass.
	action := aContext request action.
	stream := aContext responseStream.	
	stream << '<div class="sidebar-nav">
						<div class="well" style="padding: 8px 0;">
							<ul class="nav nav-list">'.
				"write superclass if available"
				realClass superclass notNil ifTrue: [
					stream << '<li class="nav-header">Superclass</li>'.
					self writeLinkTo: realClass superclass on: stream action: action ].	

				"write subclasses if available"			 
				realClass subclasses notEmpty ifTrue: [
					stream << '<li class="nav-header">Subclasses</li>'.				
					(realClass subclasses sort:   [:a :b | a name < b name ]) do: [:each | self writeLinkTo: each on: stream action: action ]].		
				        
		stream << '</ul>
				</div>			
			 </div>'.
]

{ #category : #defaults }
OHAPIHelpRequestHandler >> requestClass [
	^OHAPIHelpRequest 
]

{ #category : #private }
OHAPIHelpRequestHandler >> writeLinkTo: class on: stream action: action [
	stream << '<li><a href="api?action='.
	stream << action.
	stream << '&item='.
	stream << class name.
	stream <<  '">'.
	stream << class name.
	stream << '</a></li>'
]
