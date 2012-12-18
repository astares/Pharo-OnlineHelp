Class {
	#name : #OHTutorialItem,
	#superclass : #Object,
	#instVars : [
		'title',
		'description'
	],
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #accessing }
OHTutorialItem >> description: aByteString [ 
	 
	description := aByteString
]

{ #category : #accessing }
OHTutorialItem >> title: aByteString [ 
	 
	title := aByteString
]
