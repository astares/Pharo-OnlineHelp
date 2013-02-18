Class {
	#name : #PharoTutorial,
	#superclass : #Object,
	#category : #'OnlineHelp-Tutorials'
}

{ #category : #ideas }
PharoTutorial class >> ideas [

	"http://lists.squeakfoundation.org/pipermail/squeak-dev/2000-April/013808.html
	http://www.angelfire.com/tx4/cus/notes/smalltalk.html
	
	
	"
]

{ #category : #'online help tutorial' }
PharoTutorial class >> onlineHelpIntroPart1Page1 [

	^'
#The Pharo Online Help system

The Pharo help system is a simple framework to help documenting the Pharo system
and its packages and provide a basic introduction to first time users. 

The help content can be accessed using a typical webbrowser 
	
http://dillinger.io/	
	'
]

{ #category : #'online help tutorial' }
PharoTutorial class >> onlineHelpTutorialOn: aBuilder [
	<onlineTutorial>
	
	(aBuilder tutorial: #'Online Help Tutorial')		 
		description: 'A short overview of the Pharo environment and tools';
		addLesson:  ((aBuilder lesson: #'The Pharo Online Help')						 
						description: 'A short overview of the Pharo online help.';
						addPage: #onlineHelpIntroPart1Page1 from: self)
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPage3 [
	^'
<code>Hello</code>'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart1Page1 [
	^'
Overview
=======
To run Pharo you basically need four parts: 

 - a <font color="darkgreen"><b>virtual machine</b></font> to run pharo on your operating system platform 
 - an <font color="darkgreen"><b>image</b></font> file
 - a <font color="darkgreen"><b>changes</b></font> file
 - a <font color="darkgreen"><b>sources</b></font> file  

You can either download each part from <a href="http://files.pharo.org">http://files.pharo.org</a> or just download all of them together using the <b>"Pharo One click download"</b>  from <a href="http://www.pharo-project.org">http://www.pharo-project.org</a>
<br/><br/>
<img src="http://upload.wikimedia.org/wikipedia/commons/c/cf/Pharo.png" style="width: 50%"/><br/>

'

]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart1Page2 [	
	^'
The virtual machine
=============
Pharo is able to run on many different operating systems and platforms. This is achieved by using a platform dependent <b>virtual machine</b> (VM) that abstracts from the underlying platform and allows Pharo to run equally. 

So by default a program written in Smalltalk using Pharo is very portable and looks and behaves the same way on each platform. But Pharo also gives you the freedom to access platform specific features - so you can choose what is required for your application.

<img src="http://book.pharo-project.org/files/b5/yoxm6dildfmmg3i78kmtr711tronuw/environments.png"/>

There are virtual machines available for major operating systems like Windows, Mac, Linux, ... and also for mobiles platforms like Android. 
There are several versions of the virtual machine, but 2 most important kinds are:

 - <b>Classic</b> virtual machine
 - the new JIT based <b>Cog</b> virtual machine

Historically the Pharo VM is based on the Squeak Smalltalk virtual machine - a pluggable virtual machine which is partly written in a subset of Smalltalk (called <font color="brown"><b>Slang</b></font>) itself. There is a tool called <font color="brown"><b>VMMaker</b></font> that allows you to make changes and build your own VM if required.   

For instance there is a project called "<b>RoarVM</b>" - an adoption of the virtual machine to run Squeak and Pharo in parallel on many cores.




'

]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart1Page3 [	
	^'
The image file
==========

Pharo is a <b>dynamic object system</b> and this system is represented by a so called <font color="brown"><b>image</b></font>. The entire Smalltalk system (including all the objects in their current states)
can be persisted (saved) to a single file with an <b><i>.image</i></b> extension. <br/></br>
If you later open the image file again the Pharo system will continue to run at excactly the same point where you saved it before. You can even transfer an image file to a completely different OS platform and open it with the according virtual machine.

When you download a new fresh Pharo distribution the <b><i>default developer image</i></b> already contains tools and classes that form the Pharo system. You can modify this image to suit your needs. Typically you will add new code to create something new.

If you want to transfer your applications code to other images (like a <b><i>clean production image</i></b>) you can package it using using a tool called <font color="brown"><b>Monticello</b></font>.

For most developers coming from traditional environments this image concept is something new and hard to understand at the beginning. Once you work with it you will notice that it can make you very productive since it allows you to save the systems state at any point in time and continue later at will without a new setup. For instance you can save the system while debugging and continue to catch a bug in the debugger just the next day at exactly the same point.'

]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart1Page4 [	
	^'
The sources and changes file
====================

For various reasons, the source code associated with the image is stored in two other files:

The code of the system as originally delivered is stored in the <b>source file</b> <font color="darkblue"><b>"PharoVxx.sources"</b></font>, and the sources for everything done since that time is in the <b>changes file</b> (which must similarly be named like the image but with an <b><i>.changes</b></i> extension) <font color="darkblue"><b>"ImageFileName.changes"</b></font>.

Storing the source code in a separate file has several advantages. To begin with, if you have been working for a couple of hours, and your dog rolls over the power cord, you will still have a sequential record of all your program edits, and these can be perused and replayed with numerous tools such as changes: post-snapshot log. This feature has also saved many who got too adventurous in changing the system he or she was using.

Also, if you wish to run the system with severely limited resources, it can be operated without any source code just by removing these files.

Finally, since the changes file does not consume memory space, Pharo keeps a continuous log of all your program changes, and these can be examined and reinstated at any time. 

So the sources/changes mechanism is <u>mostly for the system</u> to handle source code, track source code changes or recover after a crash. 

<u><b>Note</b></u>: For packaging your own source code (for instance for an application) you will use other mechanisms and source code/versioning tools like <font color="brown"><b>Monticello</b></font>.

'

]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart2Page1 [
	^'
The Pharo Desktop
=============

When Pharo starts up you will see a single window called the Pharo desktop. 

<img src="http://book.pharo-project.org/files/ed/c5135wpi93rsei8s42z7ynlkghd3vr/pharostarted.png" style="width: 50%"/>

From here you can open all the necessary tools of the environment by using the <font color="red"><b>World menu</b></font>.
Just right click on the desktop to open the menu.
'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart2Page2 [
	^'
The World menu
===========

If you right click on the Pharo desktop you can open the <font color="red"><b>World menu</b></font>
Depending on the Pharo version and installed tools it may look a little bit different.
<img src="http://blog.openinworld.com/wp-content/uploads/2012/05/WorldMenu-comparison.png" style="width: 60%; padding: 20px;"/>

You can use it to access all the basic development tools like a <font color="brown"><b>Workspace</b></font>, the <font color="brown"><b>Transcript</b></font> and the <font color="brown"><b>System browser</b></font>.


'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart2Page3 [
	^'
The update mechanism
================

Pharo includes a facility for automatically updating your system from a remote Pharo server.
If you are connected to the Internet you can easily update your system to the latest state.

In the <font color="purple"><b>World menu</b></font> you will find an entry to update your system. Just right
click on the Pharo desktop in the Pharo window and select <font color="brown"><b>System -> Software update</b></font>.

<u><b>Note</b></u>: Any update changes your system - if you are unsure save your image first. 

Alternatively you can get the latest Pharo builds from

* the Pharo file server at http://files.pharo.org
* or the continuous integration (CI) server at http://ci.pharo.org
'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart2Page4 [
	^'
The settings browser
===============

All global preferences of Pharo can be viewed or changed from the Settings Browser.

In the <font color="purple"><b>World menu</b></font> you will find an entry to update your system. Just right
click on the Pharo desktop in the Pharo window and select <font color="brown"><b>System -> Settings</b></font>.

A new window will open called the "Settings Browser". On the left side you can choose the settings category and find the details on the right side. This browser allows the browsing as well as the editing of setting values.

<u><b>An example:</b></u>
If you want the Pharo desktop to fill the whole screen go to the section <font color="teal"><b>Appearance - Morphic - Fullscreen mode</b></font> and click on the checkbox.

Note that Pharo includes a complete settings framework (see [Settings Declaration][1]) for that - you can use that easily for your own applications. 


[1]: http://book.pharo-project.org/book/Tidbits/CustomizingPharo/DeclaringSetting/  "Settings Declaration"

'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart3Page1 [
	^'
The Workspace
===========
A <font color="purple"><b>workspace</b></font> is a window used as a scratchpad area where fragments of Smalltalk code can be entered, stored, edited, and evaluated



To open a workspace window in Pharo, one possibility is to bring up the World menu and then select <font color="brown"><b>Workspace</b></font>.

You can then type in any Smalltalk code inside the workspace window and <b><i>execute it</i></b> or <b><i>inspect it</i></b>. This is normally done by typing in some code, highlighting it with the mouse, and then selecting "Do it" or "Print it" or "Inspect it" from the pop-up menu. Or "Debug it" to open a debugger on the code.
'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart3Page2 [
	^'
The Transcript
==========
The <font color="purple"><b>transcript</b></font> window is often used for logging or printing results from text only code.



To bring it up use the World menu and then select <font color="brown"><b>Tools -> Transcript</b></font>. You can also type

<pre>Transcript open</pre>

in a Workspace and evaluate it.

Since the transcript behaves like a workspace you can also use it to edit text and enter Smalltalk expressions. 
To log something to the transcript window you can just evaluate the following expression:

<pre>Transcript show: ''HelloWorld''</pre>

Technically <b>Transcript</b> is a global variable you can therefore access it from anywhere in the system or your code.
'
]

{ #category : #'pharo tutorial - pages' }
PharoTutorial class >> pharoIntroPart3Page3 [
	^'
The System browser
==============
The <font color="purple"><b>system browser</b></font> gives you access to the packages and the classes of the system.


To bring it up use the World menu and then select <font color="brown"><b>System Browser</b></font>. You can also type

<pre>Browser open</pre>

in a Workspace and evaluate it. You can also open the browser directly on a class by sending the message #browse:

<pre>String browse</pre>

This opens the browser with the class already selected. You can even send the #browse method to any object in the system to browse the methods of its class:

<pre>65 asCharacter browse</pre>

The system browser (in Pharo also called "Nautilus") is a typical Smalltalk "five-pane" browser with a series of horizontally-abutting selection panes positioned above an editing pane.
The selection panes allow the user to specify first a package category and then a class, and further to refine the selection to indicate a specific class- or instance-method the implementation of which is presented in the editing pane for inspection or modification.

The system browser allows you to create new packages, classes and methods or modify existing ones. It also includes tools to refactor and restructure existing code.'
]

{ #category : #'pharo tutorial' }
PharoTutorial class >> pharoTutorialOn: aBuilder [
	<onlineTutorial>
	
	(aBuilder tutorial: #'Pharo Tutorial')		 
		description: 'A short overview of the Pharo environment and tools';
		addLesson:  ((aBuilder lesson: #'The Pharo system')						 
						description: 'A short overview of the parts that make up the Pharo system. It should help you understand what is required to run Pharo on your operating system.';
						addPage: #pharoIntroPart1Page1 from: self;
						addPage: #pharoIntroPart1Page2 from: self;	
						addPage: #pharoIntroPart1Page3 from: self;	
						addPage: #pharoIntroPart1Page4 from: self;	
						yourself);		
		addLesson:  ((aBuilder lesson: #'The Pharo environment')						 
						description: 'In this lesson you will learn how to use the Pharo environment.';
						addPage: #pharoIntroPart2Page1 from: self;
						addPage: #pharoIntroPart2Page2 from: self;	
						addPage: #pharoIntroPart2Page3 from: self;
						addPage: #pharoIntroPart2Page4 from: self;														
						yourself);
		addLesson:  ((aBuilder lesson: #'Pharo Tools')						 
						description: 'In this lesson you will learn about the default Pharo tools.';
						addPage: #pharoIntroPart3Page1 from: self;
						addPage: #pharoIntroPart3Page2 from: self;
						addPage: #pharoIntroPart3Page3 from: self;							
						yourself);
		addLesson:  ((aBuilder lesson: #'Learning Pharo')						 
						description: 'This section explains some useful resources to continue your tour with Pharo. We will tell you about the best places to learn about Pharo and the Smalltalk programming language';
						addPage: #smalltalkIntroPartXPage1 from: self;
						yourself)						
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page1 [
	^'
Literals
-----------
A literal is a piece of Smalltalk code that the compiler converts immediately to an object. There are several types of literals in Smalltalk like:

* <font color="purple"><b>Numbers</b></font>
* <font color="purple"><b>Character constants</b></font>
* <font color="purple"><b>Strings</b></font>
* <font color="purple"><b>Symbol constants</b></font>
* <font color="purple"><b>Boolean</b></font>
* <font color="purple"><b>The undefined object</b></font>
* <font color="purple"><b>Arrays of the previously described literals</b></font>
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page10 [
	^'###  Arrays ###
#### Array ####

#### Byte Arrays ####
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page2 [
	^'
### Numbers ###
#### Integers ####

Like in other programming languages you just write a number as it is:

	1

If you ask this simple number for its class you will notice that is an instance of SmallInteger (a subclass of Integer).

	1 class

If you enter a large number the system will treat it using a different class: LargePositiveInteger (also a subclass of Integer).

	536870912 class 

In Smalltalk (compared to languages like C or Java) you do not have to care about the range or basic/primitive types. So it is very
easy in Smalltalk to work with large numbers:

	200 factorial

<u>Side note</u>: <i>Integers are widely used in any programming language. Therefore integer objects (in contrast to other objects) are internally optimized for speed by the virtual machine. Nonetheless you will not notice this difference in Smalltalk since they are objects as any other objects in the system.</i>
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page3 [
	^'
### Numbers ###
#### Floats ####

Floating point numbers can be represented in Smalltalk very easily:

	4.564          "a floating point"

Note that (unlike other programming languages) Smalltalk does not represent
the result of a division directly as a Float.

	1/3
	
This will create instead a Fraction instance with numerator 1 and denominator 3.

	(3/4) asFloat

will convert the fraction object into a Float instance.

Note that you can use <b>e</b> to provide an exponent:

	-2.34e10
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page4 [
	^'
### Numbers ###
#### Scaled Decimal ####

Smalltalk also provides Scaled-decimal constants with a special class <b>ScaledDecimal</b> which does exact computations but truncates comparisons to a given number of decimals. For example

	1.23s4

means "the value 1.23, with four significant decimal digits".

#### More ####

There is a library for [abitrary precision] [1] in Smalltalk and a chapter in [PBE2 book about using Floats] [2]. 

[1]: http://code.google.com/p/arbitrary-precision-float/wiki/ArbitraryPrecisionFloatForSqueakAndPharo "abitrary precision"
[2]: http://pharobooks.gforge.inria.fr/PharoByExampleTwo-Eng/latest/Float.pdf "PBE2 book about using Floats"
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page5 [
	^'
### Characters ###
#### ASCII characters ####

There is a single class called "Character" whose instances represent a character and in a non-unicode Smalltalk system there are exactly 256 instances of this class since the first 256 characters of the ASCII character set are created uniquely.

Characters can be instantiated using the <b>$</b> operator:

	$a

Since characters are objects you can send messages to them:

	$a asUppercase

will return the character $A.

You can also access characters using its (integer) value:

	Character value: 9

to get the TAB character. You can also return the (ASCII) value of a character object:

	$a asInteger

#### Unicode characters ####

Modern smalltalk systems such as Pharo have support for Unicode characters.

	Character euro value
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page6 [
	^'### Strings ###

'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page7 [
	^'
### Symbols ###

Smalltalk provides atomic character strings, called "symbols". In Smalltalk, these behave much like strings, with the exception of being read-only (i.e. their character elements cannot be changed). Symbols are always unique and start with the <font color="brown"><b>#</b></font> sign:

	#simple

If it contains spaces it can be written like a string - but again starting with a <font color="brown"><b>#</b></font>:

	#''A unique Symbol''

You can create a symbol by sending the message <font color="brown"><b>#asSymbol</b></font> to a String instance: 

	''simple string'' asSymbol

which returns the symbol <b>#''simple string''</b>
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page8 [
	^'### Boolean ###

'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart1Page9 [
	^'### The undefined object ###

'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart2Page1 [
	^'
Objects and Messages
-----------------------------------

Everything in Smalltalk is on object, and all work is done by sending messages to objects.

To execute the following examples, open a new workspace in your Pharo environment 
and enter or copy the text there. Then select the text using the left mouse button (as in 
a word processor). 

You can then execute the text with the <b>Print it</b> command which will execute the code and print the result.

	1 negated			"Send the message #negated to the small integer 1"

As you will notice the result that is printed is <b>-1</b>.

By evaluating an expression <u>one or more messages are sent</u> to an object (here 1) and this objects <u>responds</u> with either itself or another object (here -1).  

Try some more examples:

	3 squared			"receiver object is small integer 3"
	''abc'' asUppercase	"receiver object is string ''abc'' "
	200 factorial		"sending the message #factorial"	
	''10'' asNumber       "receiver is a string and the returned object a number"
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart2Page2 [
	^'
Messages
---------------

There are exactly three kinds of messages you can send to an object: 

* <font color="purple"><b>Unary messages</b></font>
* <font color="purple"><b>Binary messages</b></font>
* <font color="purple"><b>Keyword messages</b></font>

The Smalltalk syntax is easy to remember: an object always comes first and a message follows.
So <b>first</b> the <u>object as the receiver of the message</u> and <b>then</b> <u>the message</u> you want to send.

<img src="http://yuml.me/diagram/scruffy;/class/%5BObject%5D-%5Bnote:You%20can%20send%20messages%20to%20objects.%5D.png"/>

'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart2Page3 [
	^'### Unary message ###
 	 
An unary message is just a word, there are no arguments. So it is a simple message sent to an object:

	3 negated
 

So we sent the message #negated to the receiver object 3 (which is an integer object)

Some more examples:

	''a simple string'' size
	''abcdefg'' vowels      
	$a asInteger
	#(7 7 8) size   
	#(7 7 8) last'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart2Page4 [
	^'
### Binary message ###
 	 
An binary message is a special character such as <font color="brown"><b>+ - ,</b></font> and it is followed by
exactly one argument

	3 + 4 

Note that this arithmetic example in Smalltalk is different from what you may know from other programming languages.
The two numbers are not equally treated as operands.

In Smalltalk you send the message <font color="brown"><b>+</b></font> (plus) to an object <b>3</b> with the argument object <b>4</b>. So the number 3 is the receiver of the message while 4 is the argument. There are no explicit operators as you may know from other programming languages - anything is done via message sends.

In the next example it is the other way around: the number <b>4</b> is the receiver of the plus message together with the argument object <b>3</b>:

	4 + 3 

#### Concatenation using binary messages ####

Another example for a binary message is <font color="brown"><b>,</b></font> (colon) which is for example used to concatenate strings: 

	''Hello '' , ''World''	 

Here the receiver is the string object <b>''Hello''</b>, the message is <font color="brown"><b>,</b></font> and the message argument is another string object <b>''World''</b><br/><br/>

You can even concatenate arrays with the same message:

	#(1 2 3) , #(4 5 6 7)

will return a new array #(1 2 3 4 5 6 7)

#### Comparision using binary messages ####

So even the comparision of objects is nothing more than sending a binary message:

	1 = 3

So you send the binary message  <font color="brown"><b>=</b></font> to an object and ask if it is equal to the argument object. The object itself will respond with either <font color="blue"><b>true</b></font> or <font color="blue"><b>false</b></font>.

#### Points ####

An often seen example in Smalltalk books for binary messages is the <font color="brown"><b>@</b></font> message. If you send it to an integer together
with another integer as argument it will create a Point instance with the receiver as x-coordinate and the argument as y-coordinate.

	12 @ 3

Just inspect this in a workspace and you will get a Point instance with x: 12 and y: 3.'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart2Page5 [
	^'
### Keyword message ###
 	 

'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart2Page6 [
	^'
### Message Chaining ###
 	 

'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart2Page7 [
	^'
### Cascading messages ###
 	 

'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPart2PageX [
	^'
Ans. In Chaining, one message can follow on after another. In this case the second message is sent to the object which is the result of the first message.
           anObject msg1 msg2 msg3 
In Cascading, each message is followed by a semicolon (;) and another message. In Cascading, subsequent messages are sent to the first receiver.
           anObject msg1; msg2; msg3 
 
  
 
                
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPartXPage1 [
	^'
Further references
----------------------------

One of the best ways to learn Smalltalk is to download one of the versions of Smalltalk (like <a href="http://pharo-project.org">Pharo</a>), install it, and grab a copy of one of the many free online Smalltalk books. Then dive in and get your fingers and mind immersed into the world of objects communicating with each other via messages.

Use one of the [free Smalltalk Books][1] that are [available online][1] to learn about the language or one of the two Pharo books that are also online available for free:

<table border="1">
<tr><td><a href="http://pharobyexample.org/"><img src="http://stephane.ducasse.free.fr/FreeBooks/PBE/PharoByExample.png"/></a><td></tr>
</table>
<a href="http://rmod.lille.inria.fr/pbe2/"><img style="width: 140px;" src="http://rmod.lille.inria.fr/pbe2/pictures/pbe2.jpg"/></a>

[1]: http://stephane.ducasse.free.fr/FreeBooks.html  "free Smalltalk Books"
'
]

{ #category : #'smalltalk tutorial - pages' }
PharoTutorial class >> smalltalkIntroPartXPage2 [
	^'
Smalltalk systems
----------------------------


* [Amber Smalltalk][1]
* [Dolphin Smalltalk][2]
* [GNU Smalltalk][3]
* [Cincom Smalltalk][4] 
* [Pharo] [5]
* [Redline Smalltalk][6]
* [SmalltalkMT] [7]
* [SmalltalkX] [8]
* [Squeak] [9]
* [VA Smalltalk] [10]

[1]: http://amber-lang.net  "Amber Smalltalk" 
[2]: http://www.object-arts.com "Dolphin Smalltalk"
[3]: http://smalltalk.gnu.org "GNU Smalltalk"
[4]: http://www.cincomsmalltalk.com  "Cincom Smalltalk"
[5]: http://www.pharo-project.org "Pharo"
[6]: http://www.redline.st "Redline Smalltalk"
[7]: http://objectconnect.com "SmalltalkMT"
[8]: http://www.exept.de/en/products/smalltalkx "SmalltalkX"
[9]: http://www.squeak.org "Squeak"
[10]: http://www.instantiations.com  "VA Smalltalk"
                
'
]

{ #category : #'smalltalk tutorial' }
PharoTutorial class >> smalltalkTutorialOn: aBuilder [
	<onlineTutorial>
	
	(aBuilder tutorial: #'Introduction to Smalltalk')
		description: 'An overview and introduction to the Smalltalk programming language';
		addLesson:  ((aBuilder lesson: #'Part 1: Basic Literals')					  
						description: 'Introduction to basic literals used in the Smalltalk language';
						addPage: #smalltalkIntroPart1Page1 from: self;
						addPage: #smalltalkIntroPart1Page2 from: self;	
						addPage: #smalltalkIntroPart1Page3 from: self;	
						addPage: #smalltalkIntroPart1Page4 from: self;	
						addPage: #smalltalkIntroPart1Page5 from: self;	
						addPage: #smalltalkIntroPart1Page6 from: self;	
						addPage: #smalltalkIntroPart1Page7 from: self;
						addPage: #smalltalkIntroPart1Page8 from: self;
						addPage: #smalltalkIntroPart1Page9 from: self;
						addPage: #smalltalkIntroPart1Page10 from: self;								
						yourself);		
		addLesson:  ((aBuilder lesson: #'Part 2: Objects and messages')					  
						description: 'Introduction to objects and messages';
						addPage: #smalltalkIntroPart2Page1 from: self;
						addPage: #smalltalkIntroPart2Page2 from: self;	
						addPage: #smalltalkIntroPart2Page3 from: self;	
						addPage: #smalltalkIntroPart2Page4 from: self;	
						addPage: #smalltalkIntroPart2Page5 from: self;	
						addPage: #smalltalkIntroPart2Page6 from: self;	
						addPage: #smalltalkIntroPart2Page7 from: self;							
						yourself);
		addLesson:  ((aBuilder lesson: #'Part 10: Further references')					  
						description: 'Some infos and resources on how to learn the Smalltalk language';
						addPage: #smalltalkIntroPartXPage1 from: self;	
						addPage: #smalltalkIntroPartXPage2 from: self;									 
						yourself)						
]
