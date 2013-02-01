Class {
	#name : #OHFileRequestHandler,
	#superclass : #OHHelpRequestHandler,
	#category : #'OnlineHelp-Core-Engine'
}

{ #category : #uploads }
OHFileRequestHandler >> MarkdownConverterJs [
	^ 'var Markdown;

if (typeof exports === "object" && typeof require === "function") // we''re in a CommonJS (e.g. Node.js) module
    Markdown = exports;
else
    Markdown = {};
    
// The following text is included for historical reasons, but should
// be taken with a pinch of salt; it''s not all true anymore.

//
// Wherever possible, Showdown is a straight, line-by-line port
// of the Perl version of Markdown.
//
// This is not a normal parser design; it''s basically just a
// series of string substitutions.  It''s hard to read and
// maintain this way,  but keeping Showdown close to the original
// design makes it easier to port new features.
//
// More importantly, Showdown behaves like markdown.pl in most
// edge cases.  So web applications can do client-side preview
// in Javascript, and then build identical HTML on the server.
//
// This port needs the new RegExp functionality of ECMA 262,
// 3rd Edition (i.e. Javascript 1.5).  Most modern web browsers
// should do fine.  Even with the new regular expression features,
// We do a lot of work to emulate Perl''s regex functionality.
// The tricky changes in this file mostly have the "attacklab:"
// label.  Major or self-explanatory changes don''t.
//
// Smart diff tools like Araxis Merge will be able to match up
// this file with markdown.pl in a useful way.  A little tweaking
// helps: in a copy of markdown.pl, replace "#" with "//" and
// replace "$text" with "text".  Be sure to ignore whitespace
// and line endings.
//


//
// Usage:
//
//   var text = "Markdown *rocks*.";
//
//   var converter = new Markdown.Converter();
//   var html = converter.makeHtml(text);
//
//   alert(html);
//
// Note: move the sample code to the bottom of this
// file before uncommenting it.
//

(function () {

    function identity(x) { return x; }
    function returnFalse(x) { return false; }

    function HookCollection() { }

    HookCollection.prototype = {

        chain: function (hookname, func) {
            var original = this[hookname];
            if (!original)
                throw new Error("unknown hook " + hookname);

            if (original === identity)
                this[hookname] = func;
            else
                this[hookname] = function (x) { return func(original(x)); }
        },
        set: function (hookname, func) {
            if (!this[hookname])
                throw new Error("unknown hook " + hookname);
            this[hookname] = func;
        },
        addNoop: function (hookname) {
            this[hookname] = identity;
        },
        addFalse: function (hookname) {
            this[hookname] = returnFalse;
        }
    };

    Markdown.HookCollection = HookCollection;

    // g_urls and g_titles allow arbitrary user-entered strings as keys. This
    // caused an exception (and hence stopped the rendering) when the user entered
    // e.g. [push] or [__proto__]. Adding a prefix to the actual key prevents this
    // (since no builtin property starts with "s_"). See
    // http://meta.stackoverflow.com/questions/64655/strange-wmd-bug
    // (granted, switching from Array() to Object() alone would have left only __proto__
    // to be a problem)
    function SaveHash() { }
    SaveHash.prototype = {
        set: function (key, value) {
            this["s_" + key] = value;
        },
        get: function (key) {
            return this["s_" + key];
        }
    };

    Markdown.Converter = function () {
        var pluginHooks = this.hooks = new HookCollection();
        pluginHooks.addNoop("plainLinkText");  // given a URL that was encountered by itself (without markup), should return the link text that''s to be given to this link
        pluginHooks.addNoop("preConversion");  // called with the orignal text as given to makeHtml. The result of this plugin hook is the actual markdown source that will be cooked
        pluginHooks.addNoop("postConversion"); // called with the final cooked HTML code. The result of this plugin hook is the actual output of makeHtml

        //
        // Private state of the converter instance:
        //

        // Global hashes, used by various utility routines
        var g_urls;
        var g_titles;
        var g_html_blocks;

        // Used to track when we''re inside an ordered or unordered list
        // (see _ProcessListItems() for details):
        var g_list_level;

        this.makeHtml = function (text) {

            //
            // Main function. The order in which other subs are called here is
            // essential. Link and image substitutions need to happen before
            // _EscapeSpecialCharsWithinTagAttributes(), so that any *''s or _''s in the <a>
            // and <img> tags get encoded.
            //

            // This will only happen if makeHtml on the same converter instance is called from a plugin hook.
            // Don''t do that.
            if (g_urls)
                throw new Error("Recursive call to converter.makeHtml");
        
            // Create the private state objects.
            g_urls = new SaveHash();
            g_titles = new SaveHash();
            g_html_blocks = [];
            g_list_level = 0;

            text = pluginHooks.preConversion(text);

            // attacklab: Replace ~ with ~T
            // This lets us use tilde as an escape char to avoid md5 hashes
            // The choice of character is arbitray; anything that isn''t
            // magic in Markdown will work.
            text = text.replace(/~/g, "~T");

            // attacklab: Replace $ with ~D
            // RegExp interprets $ as a special character
            // when it''s in a replacement string
            text = text.replace(/\$/g, "~D");

            // Standardize line endings
            text = text.replace(/\r\n/g, "\n"); // DOS to Unix
            text = text.replace(/\r/g, "\n"); // Mac to Unix

            // Make sure text begins and ends with a couple of newlines:
            text = "\n\n" + text + "\n\n";

            // Convert all tabs to spaces.
            text = _Detab(text);

            // Strip any lines consisting only of spaces and tabs.
            // This makes subsequent regexen easier to write, because we can
            // match consecutive blank lines with /\n+/ instead of something
            // contorted like /[ \t]*\n+/ .
            text = text.replace(/^[ \t]+$/mg, "");

            // Turn block-level HTML blocks into hash entries
            text = _HashHTMLBlocks(text);

            // Strip link definitions, store in hashes.
            text = _StripLinkDefinitions(text);

            text = _RunBlockGamut(text);

            text = _UnescapeSpecialChars(text);

            // attacklab: Restore dollar signs
            text = text.replace(/~D/g, "$$");

            // attacklab: Restore tildes
            text = text.replace(/~T/g, "~");

            text = pluginHooks.postConversion(text);

            g_html_blocks = g_titles = g_urls = null;

            return text;
        };

        function _StripLinkDefinitions(text) {
            //
            // Strips link definitions from text, stores the URLs and titles in
            // hash references.
            //

            // Link defs are in the form: ^[id]: url "optional title"

            /*
            text = text.replace(/
                ^[ ]{0,3}\[(.+)\]:  // id = $1  attacklab: g_tab_width - 1
                [ \t]*
                \n?                 // maybe *one* newline
                [ \t]*
                <?(\S+?)>?          // url = $2
                (?=\s|$)            // lookahead for whitespace instead of the lookbehind removed below
                [ \t]*
                \n?                 // maybe one newline
                [ \t]*
                (                   // (potential) title = $3
                    (\n*)           // any lines skipped = $4 attacklab: lookbehind removed
                    [ \t]+
                    ["(]
                    (.+?)           // title = $5
                    [")]
                    [ \t]*
                )?                  // title is optional
                (?:\n+|$)
            /gm, function(){...});
            */

            text = text.replace(/^[ ]{0,3}\[(.+)\]:[ \t]*\n?[ \t]*<?(\S+?)>?(?=\s|$)[ \t]*\n?[ \t]*((\n*)["(](.+?)[")][ \t]*)?(?:\n+)/gm,
                function (wholeMatch, m1, m2, m3, m4, m5) {
                    m1 = m1.toLowerCase();
                    g_urls.set(m1, _EncodeAmpsAndAngles(m2));  // Link IDs are case-insensitive
                    if (m4) {
                        // Oops, found blank lines, so it''s not a title.
                        // Put back the parenthetical statement we stole.
                        return m3;
                    } else if (m5) {
                        g_titles.set(m1, m5.replace(/"/g, "&quot;"));
                    }

                    // Completely remove the definition from the text
                    return "";
                }
            );

            return text;
        }

        function _HashHTMLBlocks(text) {

            // Hashify HTML blocks:
            // We only want to do this for block-level HTML tags, such as headers,
            // lists, and tables. That''s because we still want to wrap <p>s around
            // "paragraphs" that are wrapped in non-block-level tags, such as anchors,
            // phrase emphasis, and spans. The list of tags we''re looking for is
            // hard-coded:
            var block_tags_a = "p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math|ins|del"
            var block_tags_b = "p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math"

            // First, look for nested blocks, e.g.:
            //   <div>
            //     <div>
            //     tags for inner block must be indented.
            //     </div>
            //   </div>
            //
            // The outermost tags must start at the left margin for this to match, and
            // the inner nested divs must be indented.
            // We need to do this before the next, more liberal match, because the next
            // match will start at the first `<div>` and stop at the first `</div>`.

            // attacklab: This regex can be expensive when it fails.

            /*
            text = text.replace(/
                (                       // save in $1
                    ^                   // start of line  (with /m)
                    <($block_tags_a)    // start tag = $2
                    \b                  // word break
                                        // attacklab: hack around khtml/pcre bug...
                    [^\r]*?\n           // any number of lines, minimally matching
                    </\2>               // the matching end tag
                    [ \t]*              // trailing spaces/tabs
                    (?=\n+)             // followed by a newline
                )                       // attacklab: there are sentinel newlines at end of document
            /gm,function(){...}};
            */
            text = text.replace(/^(<(p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math|ins|del)\b[^\r]*?\n<\/\2>[ \t]*(?=\n+))/gm, hashElement);

            //
            // Now match more liberally, simply from `\n<tag>` to `</tag>\n`
            //

            /*
            text = text.replace(/
                (                       // save in $1
                    ^                   // start of line  (with /m)
                    <($block_tags_b)    // start tag = $2
                    \b                  // word break
                                        // attacklab: hack around khtml/pcre bug...
                    [^\r]*?             // any number of lines, minimally matching
                    .*</\2>             // the matching end tag
                    [ \t]*              // trailing spaces/tabs
                    (?=\n+)             // followed by a newline
                )                       // attacklab: there are sentinel newlines at end of document
            /gm,function(){...}};
            */
            text = text.replace(/^(<(p|div|h[1-6]|blockquote|pre|table|dl|ol|ul|script|noscript|form|fieldset|iframe|math)\b[^\r]*?.*<\/\2>[ \t]*(?=\n+)\n)/gm, hashElement);

            // Special case just for <hr />. It was easier to make a special case than
            // to make the other regex more complicated.  

            /*
            text = text.replace(/
                \n                  // Starting after a blank line
                [ ]{0,3}
                (                   // save in $1
                    (<(hr)          // start tag = $2
                        \b          // word break
                        ([^<>])*?
                    \/?>)           // the matching end tag
                    [ \t]*
                    (?=\n{2,})      // followed by a blank line
                )
            /g,hashElement);
            */
            text = text.replace(/\n[ ]{0,3}((<(hr)\b([^<>])*?\/?>)[ \t]*(?=\n{2,}))/g, hashElement);

            // Special case for standalone HTML comments:

            /*
            text = text.replace(/
                \n\n                                            // Starting after a blank line
                [ ]{0,3}                                        // attacklab: g_tab_width - 1
                (                                               // save in $1
                    <!
                    (--(?:|(?:[^>-]|-[^>])(?:[^-]|-[^-])*)--)   // see http://www.w3.org/TR/html-markup/syntax.html#comments and http://meta.stackoverflow.com/q/95256
                    >
                    [ \t]*
                    (?=\n{2,})                                  // followed by a blank line
                )
            /g,hashElement);
            */
            text = text.replace(/\n\n[ ]{0,3}(<!(--(?:|(?:[^>-]|-[^>])(?:[^-]|-[^-])*)--)>[ \t]*(?=\n{2,}))/g, hashElement);

            // PHP and ASP-style processor instructions (<?...?> and <%...%>)

            /*
            text = text.replace(/
                (?:
                    \n\n            // Starting after a blank line
                )
                (                   // save in $1
                    [ ]{0,3}        // attacklab: g_tab_width - 1
                    (?:
                        <([?%])     // $2
                        [^\r]*?
                        \2>
                    )
                    [ \t]*
                    (?=\n{2,})      // followed by a blank line
                )
            /g,hashElement);
            */
            text = text.replace(/(?:\n\n)([ ]{0,3}(?:<([?%])[^\r]*?\2>)[ \t]*(?=\n{2,}))/g, hashElement);

            return text;
        }

        function hashElement(wholeMatch, m1) {
            var blockText = m1;

            // Undo double lines
            blockText = blockText.replace(/^\n+/, "");

            // strip trailing blank lines
            blockText = blockText.replace(/\n+$/g, "");

            // Replace the element text with a marker ("~KxK" where x is its key)
            blockText = "\n\n~K" + (g_html_blocks.push(blockText) - 1) + "K\n\n";

            return blockText;
        }

        function _RunBlockGamut(text, doNotUnhash) {
            //
            // These are all the transformations that form block-level
            // tags like paragraphs, headers, and list items.
            //
            text = _DoHeaders(text);

            // Do Horizontal Rules:
            var replacement = "<hr />\n";
            text = text.replace(/^[ ]{0,2}([ ]?\*[ ]?){3,}[ \t]*$/gm, replacement);
            text = text.replace(/^[ ]{0,2}([ ]?-[ ]?){3,}[ \t]*$/gm, replacement);
            text = text.replace(/^[ ]{0,2}([ ]?_[ ]?){3,}[ \t]*$/gm, replacement);

            text = _DoLists(text);
            text = _DoCodeBlocks(text);
            text = _DoBlockQuotes(text);

            // We already ran _HashHTMLBlocks() before, in Markdown(), but that
            // was to escape raw HTML in the original Markdown source. This time,
            // we''re escaping the markup we''ve just created, so that we don''t wrap
            // <p> tags around block-level tags.
            text = _HashHTMLBlocks(text);
            text = _FormParagraphs(text, doNotUnhash);

            return text;
        }

        function _RunSpanGamut(text) {
            //
            // These are all the transformations that occur *within* block-level
            // tags like paragraphs, headers, and list items.
            //

            text = _DoCodeSpans(text);
            text = _EscapeSpecialCharsWithinTagAttributes(text);
            text = _EncodeBackslashEscapes(text);

            // Process anchor and image tags. Images must come first,
            // because ![foo][f] looks like an anchor.
            text = _DoImages(text);
            text = _DoAnchors(text);

            // Make links out of things like `<http://example.com/>`
            // Must come after _DoAnchors(), because you can use < and >
            // delimiters in inline links like [this](<url>).
            text = _DoAutoLinks(text);
            
            text = text.replace(/~P/g, "://"); // put in place to prevent autolinking; reset now
            
            text = _EncodeAmpsAndAngles(text);
            text = _DoItalicsAndBold(text);

            // Do hard breaks:
            text = text.replace(/  +\n/g, " <br>\n");

            return text;
        }

        function _EscapeSpecialCharsWithinTagAttributes(text) {
            //
            // Within tags -- meaning between < and > -- encode [\ ` * _] so they
            // don''t conflict with their use in Markdown for code, italics and strong.
            //

            // Build a regex to find HTML tags and comments.  See Friedl''s 
            // "Mastering Regular Expressions", 2nd Ed., pp. 200-201.

            // SE: changed the comment part of the regex

            var regex = /(<[a-z\/!$]("[^"]*"|''[^'']*''|[^''">])*>|<!(--(?:|(?:[^>-]|-[^>])(?:[^-]|-[^-])*)--)>)/gi;

            text = text.replace(regex, function (wholeMatch) {
                var tag = wholeMatch.replace(/(.)<\/?code>(?=.)/g, "$1`");
                tag = escapeCharacters(tag, wholeMatch.charAt(1) == "!" ? "\\`*_/" : "\\`*_"); // also escape slashes in comments to prevent autolinking there -- http://meta.stackoverflow.com/questions/95987
                return tag;
            });

            return text;
        }

        function _DoAnchors(text) {
            //
            // Turn Markdown link shortcuts into XHTML <a> tags.
            //
            //
            // First, handle reference-style links: [link text] [id]
            //

            /*
            text = text.replace(/
                (                           // wrap whole match in $1
                    \[
                    (
                        (?:
                            \[[^\]]*\]      // allow brackets nested one level
                            |
                            [^\[]           // or anything else
                        )*
                    )
                    \]

                    [ ]?                    // one optional space
                    (?:\n[ ]*)?             // one optional newline followed by spaces

                    \[
                    (.*?)                   // id = $3
                    \]
                )
                ()()()()                    // pad remaining backreferences
            /g, writeAnchorTag);
            */
            text = text.replace(/(\[((?:\[[^\]]*\]|[^\[\]])*)\][ ]?(?:\n[ ]*)?\[(.*?)\])()()()()/g, writeAnchorTag);

            //
            // Next, inline-style links: [link text](url "optional title")
            //

            /*
            text = text.replace(/
                (                           // wrap whole match in $1
                    \[
                    (
                        (?:
                            \[[^\]]*\]      // allow brackets nested one level
                            |
                            [^\[\]]         // or anything else
                        )*
                    )
                    \]
                    \(                      // literal paren
                    [ \t]*
                    ()                      // no id, so leave $3 empty
                    <?(                     // href = $4
                        (?:
                            \([^)]*\)       // allow one level of (correctly nested) parens (think MSDN)
                            |
                            [^()\s]
                        )*?
                    )>?                
                    [ \t]*
                    (                       // $5
                        ([''"])              // quote char = $6
                        (.*?)               // Title = $7
                        \6                  // matching quote
                        [ \t]*              // ignore any spaces/tabs between closing quote and )
                    )?                      // title is optional
                    \)
                )
            /g, writeAnchorTag);
            */

            text = text.replace(/(\[((?:\[[^\]]*\]|[^\[\]])*)\]\([ \t]*()<?((?:\([^)]*\)|[^()\s])*?)>?[ \t]*(([''"])(.*?)\6[ \t]*)?\))/g, writeAnchorTag);

            //
            // Last, handle reference-style shortcuts: [link text]
            // These must come last in case you''ve also got [link test][1]
            // or [link test](/foo)
            //

            /*
            text = text.replace(/
                (                   // wrap whole match in $1
                    \[
                    ([^\[\]]+)      // link text = $2; can''t contain ''['' or '']''
                    \]
                )
                ()()()()()          // pad rest of backreferences
            /g, writeAnchorTag);
            */
            text = text.replace(/(\[([^\[\]]+)\])()()()()()/g, writeAnchorTag);

            return text;
        }

        function writeAnchorTag(wholeMatch, m1, m2, m3, m4, m5, m6, m7) {
            if (m7 == undefined) m7 = "";
            var whole_match = m1;
            var link_text = m2.replace(/:\/\//g, "~P"); // to prevent auto-linking withing the link. will be converted back after the auto-linker runs
            var link_id = m3.toLowerCase();
            var url = m4;
            var title = m7;

            if (url == "") {
                if (link_id == "") {
                    // lower-case and turn embedded newlines into spaces
                    link_id = link_text.toLowerCase().replace(/ ?\n/g, " ");
                }
                url = "#" + link_id;

                if (g_urls.get(link_id) != undefined) {
                    url = g_urls.get(link_id);
                    if (g_titles.get(link_id) != undefined) {
                        title = g_titles.get(link_id);
                    }
                }
                else {
                    if (whole_match.search(/\(\s*\)$/m) > -1) {
                        // Special case for explicit empty url
                        url = "";
                    } else {
                        return whole_match;
                    }
                }
            }
            url = encodeProblemUrlChars(url);
            url = escapeCharacters(url, "*_");
            var result = "<a href=\"" + url + "\"";

            if (title != "") {
                title = attributeEncode(title);
                title = escapeCharacters(title, "*_");
                result += " title=\"" + title + "\"";
            }

            result += ">" + link_text + "</a>";

            return result;
        }

        function _DoImages(text) {
            //
            // Turn Markdown image shortcuts into <img> tags.
            //

            //
            // First, handle reference-style labeled images: ![alt text][id]
            //

            /*
            text = text.replace(/
                (                   // wrap whole match in $1
                    !\[
                    (.*?)           // alt text = $2
                    \]

                    [ ]?            // one optional space
                    (?:\n[ ]*)?     // one optional newline followed by spaces

                    \[
                    (.*?)           // id = $3
                    \]
                )
                ()()()()            // pad rest of backreferences
            /g, writeImageTag);
            */
            text = text.replace(/(!\[(.*?)\][ ]?(?:\n[ ]*)?\[(.*?)\])()()()()/g, writeImageTag);

            //
            // Next, handle inline images:  ![alt text](url "optional title")
            // Don''t forget: encode * and _

            /*
            text = text.replace(/
                (                   // wrap whole match in $1
                    !\[
                    (.*?)           // alt text = $2
                    \]
                    \s?             // One optional whitespace character
                    \(              // literal paren
                    [ \t]*
                    ()              // no id, so leave $3 empty
                    <?(\S+?)>?      // src url = $4
                    [ \t]*
                    (               // $5
                        ([''"])      // quote char = $6
                        (.*?)       // title = $7
                        \6          // matching quote
                        [ \t]*
                    )?              // title is optional
                    \)
                )
            /g, writeImageTag);
            */
            text = text.replace(/(!\[(.*?)\]\s?\([ \t]*()<?(\S+?)>?[ \t]*(([''"])(.*?)\6[ \t]*)?\))/g, writeImageTag);

            return text;
        }
        
        function attributeEncode(text) {
            // unconditionally replace angle brackets here -- what ends up in an attribute (e.g. alt or title)
            // never makes sense to have verbatim HTML in it (and the sanitizer would totally break it)
            return text.replace(/>/g, "&gt;").replace(/</g, "&lt;").replace(/"/g, "&quot;");
        }

        function writeImageTag(wholeMatch, m1, m2, m3, m4, m5, m6, m7) {
            var whole_match = m1;
            var alt_text = m2;
            var link_id = m3.toLowerCase();
            var url = m4;
            var title = m7;

            if (!title) title = "";

            if (url == "") {
                if (link_id == "") {
                    // lower-case and turn embedded newlines into spaces
                    link_id = alt_text.toLowerCase().replace(/ ?\n/g, " ");
                }
                url = "#" + link_id;

                if (g_urls.get(link_id) != undefined) {
                    url = g_urls.get(link_id);
                    if (g_titles.get(link_id) != undefined) {
                        title = g_titles.get(link_id);
                    }
                }
                else {
                    return whole_match;
                }
            }
            
            alt_text = escapeCharacters(attributeEncode(alt_text), "*_[]()");
            url = escapeCharacters(url, "*_");
            var result = "<img src=\"" + url + "\" alt=\"" + alt_text + "\"";

            // attacklab: Markdown.pl adds empty title attributes to images.
            // Replicate this bug.

            //if (title != "") {
            title = attributeEncode(title);
            title = escapeCharacters(title, "*_");
            result += " title=\"" + title + "\"";
            //}

            result += " />";

            return result;
        }

        function _DoHeaders(text) {

            // Setext-style headers:
            //  Header 1
            //  ========
            //  
            //  Header 2
            //  --------
            //
            text = text.replace(/^(.+)[ \t]*\n=+[ \t]*\n+/gm,
                function (wholeMatch, m1) { return "<h1>" + _RunSpanGamut(m1) + "</h1>\n\n"; }
            );

            text = text.replace(/^(.+)[ \t]*\n-+[ \t]*\n+/gm,
                function (matchFound, m1) { return "<h2>" + _RunSpanGamut(m1) + "</h2>\n\n"; }
            );

            // atx-style headers:
            //  # Header 1
            //  ## Header 2
            //  ## Header 2 with closing hashes ##
            //  ...
            //  ###### Header 6
            //

            /*
            text = text.replace(/
                ^(\#{1,6})      // $1 = string of #''s
                [ \t]*
                (.+?)           // $2 = Header text
                [ \t]*
                \#*             // optional closing #''s (not counted)
                \n+
            /gm, function() {...});
            */

            text = text.replace(/^(\#{1,6})[ \t]*(.+?)[ \t]*\#*\n+/gm,
                function (wholeMatch, m1, m2) {
                    var h_level = m1.length;
                    return "<h" + h_level + ">" + _RunSpanGamut(m2) + "</h" + h_level + ">\n\n";
                }
            );

            return text;
        }

        function _DoLists(text) {
            //
            // Form HTML ordered (numbered) and unordered (bulleted) lists.
            //

            // attacklab: add sentinel to hack around khtml/safari bug:
            // http://bugs.webkit.org/show_bug.cgi?id=11231
            text += "~0";

            // Re-usable pattern to match any entirel ul or ol list:

            /*
            var whole_list = /
                (                                   // $1 = whole list
                    (                               // $2
                        [ ]{0,3}                    // attacklab: g_tab_width - 1
                        ([*+-]|\d+[.])              // $3 = first list item marker
                        [ \t]+
                    )
                    [^\r]+?
                    (                               // $4
                        ~0                          // sentinel for workaround; should be $
                        |
                        \n{2,}
                        (?=\S)
                        (?!                         // Negative lookahead for another list item marker
                            [ \t]*
                            (?:[*+-]|\d+[.])[ \t]+
                        )
                    )
                )
            /g
            */
            var whole_list = /^(([ ]{0,3}([*+-]|\d+[.])[ \t]+)[^\r]+?(~0|\n{2,}(?=\S)(?![ \t]*(?:[*+-]|\d+[.])[ \t]+)))/gm;

            if (g_list_level) {
                text = text.replace(whole_list, function (wholeMatch, m1, m2) {
                    var list = m1;
                    var list_type = (m2.search(/[*+-]/g) > -1) ? "ul" : "ol";

                    var result = _ProcessListItems(list, list_type);

                    // Trim any trailing whitespace, to put the closing `</$list_type>`
                    // up on the preceding line, to get it past the current stupid
                    // HTML block parser. This is a hack to work around the terrible
                    // hack that is the HTML block parser.
                    result = result.replace(/\s+$/, "");
                    result = "<" + list_type + ">" + result + "</" + list_type + ">\n";
                    return result;
                });
            } else {
                whole_list = /(\n\n|^\n?)(([ ]{0,3}([*+-]|\d+[.])[ \t]+)[^\r]+?(~0|\n{2,}(?=\S)(?![ \t]*(?:[*+-]|\d+[.])[ \t]+)))/g;
                text = text.replace(whole_list, function (wholeMatch, m1, m2, m3) {
                    var runup = m1;
                    var list = m2;

                    var list_type = (m3.search(/[*+-]/g) > -1) ? "ul" : "ol";
                    var result = _ProcessListItems(list, list_type);
                    result = runup + "<" + list_type + ">\n" + result + "</" + list_type + ">\n";
                    return result;
                });
            }

            // attacklab: strip sentinel
            text = text.replace(/~0/, "");

            return text;
        }

        var _listItemMarkers = { ol: "\\d+[.]", ul: "[*+-]" };

        function _ProcessListItems(list_str, list_type) {
            //
            //  Process the contents of a single ordered or unordered list, splitting it
            //  into individual list items.
            //
            //  list_type is either "ul" or "ol".

            // The $g_list_level global keeps track of when we''re inside a list.
            // Each time we enter a list, we increment it; when we leave a list,
            // we decrement. If it''s zero, we''re not in a list anymore.
            //
            // We do this because when we''re not inside a list, we want to treat
            // something like this:
            //
            //    I recommend upgrading to version
            //    8. Oops, now this line is treated
            //    as a sub-list.
            //
            // As a single paragraph, despite the fact that the second line starts
            // with a digit-period-space sequence.
            //
            // Whereas when we''re inside a list (or sub-list), that line will be
            // treated as the start of a sub-list. What a kludge, huh? This is
            // an aspect of Markdown''s syntax that''s hard to parse perfectly
            // without resorting to mind-reading. Perhaps the solution is to
            // change the syntax rules such that sub-lists must start with a
            // starting cardinal number; e.g. "1." or "a.".

            g_list_level++;

            // trim trailing blank lines:
            list_str = list_str.replace(/\n{2,}$/, "\n");

            // attacklab: add sentinel to emulate \z
            list_str += "~0";

            // In the original attacklab showdown, list_type was not given to this function, and anything
            // that matched /[*+-]|\d+[.]/ would just create the next <li>, causing this mismatch:
            //
            //  Markdown          rendered by WMD        rendered by MarkdownSharp
            //  ------------------------------------------------------------------
            //  1. first          1. first               1. first
            //  2. second         2. second              2. second
            //  - third           3. third                   * third
            //
            // We changed this to behave identical to MarkdownSharp. This is the constructed RegEx,
            // with {MARKER} being one of \d+[.] or [*+-], depending on list_type:
        
            /*
            list_str = list_str.replace(/
                (^[ \t]*)                       // leading whitespace = $1
                ({MARKER}) [ \t]+               // list marker = $2
                ([^\r]+?                        // list item text   = $3
                    (\n+)
                )
                (?=
                    (~0 | \2 ({MARKER}) [ \t]+)
                )
            /gm, function(){...});
            */

            var marker = _listItemMarkers[list_type];
            var re = new RegExp("(^[ \\t]*)(" + marker + ")[ \\t]+([^\\r]+?(\\n+))(?=(~0|\\1(" + marker + ")[ \\t]+))", "gm");
            var last_item_had_a_double_newline = false;
            list_str = list_str.replace(re,
                function (wholeMatch, m1, m2, m3) {
                    var item = m3;
                    var leading_space = m1;
                    var ends_with_double_newline = /\n\n$/.test(item);
                    var contains_double_newline = ends_with_double_newline || item.search(/\n{2,}/) > -1;

                    if (contains_double_newline || last_item_had_a_double_newline) {
                        item = _RunBlockGamut(_Outdent(item), /* doNotUnhash = */true);
                    }
                    else {
                        // Recursion for sub-lists:
                        item = _DoLists(_Outdent(item));
                        item = item.replace(/\n$/, ""); // chomp(item)
                        item = _RunSpanGamut(item);
                    }
                    last_item_had_a_double_newline = ends_with_double_newline;
                    return "<li>" + item + "</li>\n";
                }
            );

            // attacklab: strip sentinel
            list_str = list_str.replace(/~0/g, "");

            g_list_level--;
            return list_str;
        }

        function _DoCodeBlocks(text) {
            //
            //  Process Markdown `<pre><code>` blocks.
            //  

            /*
            text = text.replace(/
                (?:\n\n|^)
                (                               // $1 = the code block -- one or more lines, starting with a space/tab
                    (?:
                        (?:[ ]{4}|\t)           // Lines must start with a tab or a tab-width of spaces - attacklab: g_tab_width
                        .*\n+
                    )+
                )
                (\n*[ ]{0,3}[^ \t\n]|(?=~0))    // attacklab: g_tab_width
            /g ,function(){...});
            */

            // attacklab: sentinel workarounds for lack of \A and \Z, safari\khtml bug
            text += "~0";

            text = text.replace(/(?:\n\n|^)((?:(?:[ ]{4}|\t).*\n+)+)(\n*[ ]{0,3}[^ \t\n]|(?=~0))/g,
                function (wholeMatch, m1, m2) {
                    var codeblock = m1;
                    var nextChar = m2;

                    codeblock = _EncodeCode(_Outdent(codeblock));
                    codeblock = _Detab(codeblock);
                    codeblock = codeblock.replace(/^\n+/g, ""); // trim leading newlines
                    codeblock = codeblock.replace(/\n+$/g, ""); // trim trailing whitespace

                    codeblock = "<pre><code>" + codeblock + "\n</code></pre>";

                    return "\n\n" + codeblock + "\n\n" + nextChar;
                }
            );

            // attacklab: strip sentinel
            text = text.replace(/~0/, "");

            return text;
        }

        function hashBlock(text) {
            text = text.replace(/(^\n+|\n+$)/g, "");
            return "\n\n~K" + (g_html_blocks.push(text) - 1) + "K\n\n";
        }

        function _DoCodeSpans(text) {
            //
            // * Backtick quotes are used for <code></code> spans.
            // 
            // * You can use multiple backticks as the delimiters if you want to
            //   include literal backticks in the code span. So, this input:
            //     
            //      Just type ``foo `bar` baz`` at the prompt.
            //     
            //   Will translate to:
            //     
            //      <p>Just type <code>foo `bar` baz</code> at the prompt.</p>
            //     
            //   There''s no arbitrary limit to the number of backticks you
            //   can use as delimters. If you need three consecutive backticks
            //   in your code, use four for delimiters, etc.
            //
            // * You can use spaces to get literal backticks at the edges:
            //     
            //      ... type `` `bar` `` ...
            //     
            //   Turns to:
            //     
            //      ... type <code>`bar`</code> ...
            //

            /*
            text = text.replace(/
                (^|[^\\])       // Character before opening ` can''t be a backslash
                (`+)            // $2 = Opening run of `
                (               // $3 = The code block
                    [^\r]*?
                    [^`]        // attacklab: work around lack of lookbehind
                )
                \2              // Matching closer
                (?!`)
            /gm, function(){...});
            */

            text = text.replace(/(^|[^\\])(`+)([^\r]*?[^`])\2(?!`)/gm,
                function (wholeMatch, m1, m2, m3, m4) {
                    var c = m3;
                    c = c.replace(/^([ \t]*)/g, ""); // leading whitespace
                    c = c.replace(/[ \t]*$/g, ""); // trailing whitespace
                    c = _EncodeCode(c);
                    c = c.replace(/:\/\//g, "~P"); // to prevent auto-linking. Not necessary in code *blocks*, but in code spans. Will be converted back after the auto-linker runs.
                    return m1 + "<code>" + c + "</code>";
                }
            );

            return text;
        }

        function _EncodeCode(text) {
            //
            // Encode/escape certain characters inside Markdown code runs.
            // The point is that in code, these characters are literals,
            // and lose their special Markdown meanings.
            //
            // Encode all ampersands; HTML entities are not
            // entities within a Markdown code span.
            text = text.replace(/&/g, "&amp;");

            // Do the angle bracket song and dance:
            text = text.replace(/</g, "&lt;");
            text = text.replace(/>/g, "&gt;");

            // Now, escape characters that are magic in Markdown:
            text = escapeCharacters(text, "\*_{}[]\\", false);

            // jj the line above breaks this:
            //---

            //* Item

            //   1. Subitem

            //            special char: *
            //---

            return text;
        }

        function _DoItalicsAndBold(text) {

            // <strong> must go first:
            text = text.replace(/([\W_]|^)(\*\*|__)(?=\S)([^\r]*?\S[\*_]*)\2([\W_]|$)/g,
            "$1<strong>$3</strong>$4");

            text = text.replace(/([\W_]|^)(\*|_)(?=\S)([^\r\*_]*?\S)\2([\W_]|$)/g,
            "$1<em>$3</em>$4");

            return text;
        }

        function _DoBlockQuotes(text) {

            /*
            text = text.replace(/
                (                           // Wrap whole match in $1
                    (
                        ^[ \t]*>[ \t]?      // ''>'' at the start of a line
                        .+\n                // rest of the first line
                        (.+\n)*             // subsequent consecutive lines
                        \n*                 // blanks
                    )+
                )
            /gm, function(){...});
            */

            text = text.replace(/((^[ \t]*>[ \t]?.+\n(.+\n)*\n*)+)/gm,
                function (wholeMatch, m1) {
                    var bq = m1;

                    // attacklab: hack around Konqueror 3.5.4 bug:
                    // "----------bug".replace(/^-/g,"") == "bug"

                    bq = bq.replace(/^[ \t]*>[ \t]?/gm, "~0"); // trim one level of quoting

                    // attacklab: clean up hack
                    bq = bq.replace(/~0/g, "");

                    bq = bq.replace(/^[ \t]+$/gm, "");     // trim whitespace-only lines
                    bq = _RunBlockGamut(bq);             // recurse

                    bq = bq.replace(/(^|\n)/g, "$1  ");
                    // These leading spaces screw with <pre> content, so we need to fix that:
                    bq = bq.replace(
                            /(\s*<pre>[^\r]+?<\/pre>)/gm,
                        function (wholeMatch, m1) {
                            var pre = m1;
                            // attacklab: hack around Konqueror 3.5.4 bug:
                            pre = pre.replace(/^  /mg, "~0");
                            pre = pre.replace(/~0/g, "");
                            return pre;
                        });

                    return hashBlock("<blockquote>\n" + bq + "\n</blockquote>");
                }
            );
            return text;
        }

        function _FormParagraphs(text, doNotUnhash) {
            //
            //  Params:
            //    $text - string to process with html <p> tags
            //

            // Strip leading and trailing lines:
            text = text.replace(/^\n+/g, "");
            text = text.replace(/\n+$/g, "");

            var grafs = text.split(/\n{2,}/g);
            var grafsOut = [];
            
            var markerRe = /~K(\d+)K/;

            //
            // Wrap <p> tags.
            //
            var end = grafs.length;
            for (var i = 0; i < end; i++) {
                var str = grafs[i];

                // if this is an HTML marker, copy it
                if (markerRe.test(str)) {
                    grafsOut.push(str);
                }
                else if (/\S/.test(str)) {
                    str = _RunSpanGamut(str);
                    str = str.replace(/^([ \t]*)/g, "<p>");
                    str += "</p>"
                    grafsOut.push(str);
                }

            }
            //
            // Unhashify HTML blocks
            //
            if (!doNotUnhash) {
                end = grafsOut.length;
                for (var i = 0; i < end; i++) {
                    var foundAny = true;
                    while (foundAny) { // we may need several runs, since the data may be nested
                        foundAny = false;
                        grafsOut[i] = grafsOut[i].replace(/~K(\d+)K/g, function (wholeMatch, id) {
                            foundAny = true;
                            return g_html_blocks[id];
                        });
                    }
                }
            }
            return grafsOut.join("\n\n");
        }

        function _EncodeAmpsAndAngles(text) {
            // Smart processing for ampersands and angle brackets that need to be encoded.

            // Ampersand-encoding based entirely on Nat Irons''s Amputator MT plugin:
            //   http://bumppo.net/projects/amputator/
            text = text.replace(/&(?!#?[xX]?(?:[0-9a-fA-F]+|\w+);)/g, "&amp;");

            // Encode naked <''s
            text = text.replace(/<(?![a-z\/?\$!])/gi, "&lt;");

            return text;
        }

        function _EncodeBackslashEscapes(text) {
            //
            //   Parameter:  String.
            //   Returns:    The string, with after processing the following backslash
            //               escape sequences.
            //

            // attacklab: The polite way to do this is with the new
            // escapeCharacters() function:
            //
            //     text = escapeCharacters(text,"\\",true);
            //     text = escapeCharacters(text,"`*_{}[]()>#+-.!",true);
            //
            // ...but we''re sidestepping its use of the (slow) RegExp constructor
            // as an optimization for Firefox.  This function gets called a LOT.

            text = text.replace(/\\(\\)/g, escapeCharacters_callback);
            text = text.replace(/\\([`*_{}\[\]()>#+-.!])/g, escapeCharacters_callback);
            return text;
        }

        function _DoAutoLinks(text) {

            // note that at this point, all other URL in the text are already hyperlinked as <a href=""></a>
            // *except* for the <http://www.foo.com> case

            // automatically add < and > around unadorned raw hyperlinks
            // must be preceded by space/BOF and followed by non-word/EOF character    
            text = text.replace(/(^|\s)(https?|ftp)(:\/\/[-A-Z0-9+&@#\/%?=~_|\[\]\(\)!:,\.;]*[-A-Z0-9+&@#\/%=~_|\[\]])($|\W)/gi, "$1<$2$3>$4");

            //  autolink anything like <http://example.com>
            
            var replacer = function (wholematch, m1) { return "<a href=\"" + m1 + "\">" + pluginHooks.plainLinkText(m1) + "</a>"; }
            text = text.replace(/<((https?|ftp):[^''">\s]+)>/gi, replacer);

            // Email addresses: <address@domain.foo>
            /*
            text = text.replace(/
                <
                (?:mailto:)?
                (
                    [-.\w]+
                    \@
                    [-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+
                )
                >
            /gi, _DoAutoLinks_callback());
            */

            /* disabling email autolinking, since we don''t do that on the server, either
            text = text.replace(/<(?:mailto:)?([-.\w]+\@[-a-z0-9]+(\.[-a-z0-9]+)*\.[a-z]+)>/gi,
                function(wholeMatch,m1) {
                    return _EncodeEmailAddress( _UnescapeSpecialChars(m1) );
                }
            );
            */
            return text;
        }

        function _UnescapeSpecialChars(text) {
            //
            // Swap back in all the special characters we''ve hidden.
            //
            text = text.replace(/~E(\d+)E/g,
                function (wholeMatch, m1) {
                    var charCodeToReplace = parseInt(m1);
                    return String.fromCharCode(charCodeToReplace);
                }
            );
            return text;
        }

        function _Outdent(text) {
            //
            // Remove one level of line-leading tabs or spaces
            //

            // attacklab: hack around Konqueror 3.5.4 bug:
            // "----------bug".replace(/^-/g,"") == "bug"

            text = text.replace(/^(\t|[ ]{1,4})/gm, "~0"); // attacklab: g_tab_width

            // attacklab: clean up hack
            text = text.replace(/~0/g, "")

            return text;
        }

        function _Detab(text) {
            if (!/\t/.test(text))
                return text;

            var spaces = ["    ", "   ", "  ", " "],
            skew = 0,
            v;

            return text.replace(/[\n\t]/g, function (match, offset) {
                if (match === "\n") {
                    skew = offset + 1;
                    return match;
                }
                v = (offset - skew) % 4;
                skew = offset + 1;
                return spaces[v];
            });
        }

        //
        //  attacklab: Utility functions
        //

        var _problemUrlChars = /(?:["''*()[\]:]|~D)/g;

        // hex-encodes some unusual "problem" chars in URLs to avoid URL detection problems 
        function encodeProblemUrlChars(url) {
            if (!url)
                return "";

            var len = url.length;

            return url.replace(_problemUrlChars, function (match, offset) {
                if (match == "~D") // escape for dollar
                    return "%24";
                if (match == ":") {
                    if (offset == len - 1 || /[0-9\/]/.test(url.charAt(offset + 1)))
                        return ":"
                }
                return "%" + match.charCodeAt(0).toString(16);
            });
        }


        function escapeCharacters(text, charsToEscape, afterBackslash) {
            // First we have to escape the escape characters so that
            // we can build a character class out of them
            var regexString = "([" + charsToEscape.replace(/([\[\]\\])/g, "\\$1") + "])";

            if (afterBackslash) {
                regexString = "\\\\" + regexString;
            }

            var regex = new RegExp(regexString, "g");
            text = text.replace(regex, escapeCharacters_callback);

            return text;
        }


        function escapeCharacters_callback(wholeMatch, m1) {
            var charCodeToEscape = m1.charCodeAt(0);
            return "~E" + charCodeToEscape + "E";
        }

    }; // end of the Markdown.Converter constructor

})();
'
]

{ #category : #uploads }
OHFileRequestHandler >> MarkdownEditorJs [
	^ '// needs Markdown.Converter.js at the moment

(function () {

    var util = {},
        position = {},
        ui = {},
        doc = window.document,
        re = window.RegExp,
        nav = window.navigator,
        SETTINGS = { lineLength: 72 },

    // Used to work around some browser bugs where we can''t use feature testing.
        uaSniffed = {
            isIE: /msie/.test(nav.userAgent.toLowerCase()),
            isIE_5or6: /msie 6/.test(nav.userAgent.toLowerCase()) || /msie 5/.test(nav.userAgent.toLowerCase()),
            isOpera: /opera/.test(nav.userAgent.toLowerCase())
        };

    var defaultsStrings = {
        bold: "Strong <strong> Ctrl+B",
        boldexample: "strong text",

        italic: "Emphasis <em> Ctrl+I",
        italicexample: "emphasized text",

        link: "Hyperlink <a> Ctrl+L",
        linkdescription: "enter link description here",
        linkdialog: "<p><b>Insert Hyperlink</b></p><p>http://example.com/ \"optional title\"</p>",

        quote: "Blockquote <blockquote> Ctrl+Q",
        quoteexample: "Blockquote",

        code: "Code Sample <pre><code> Ctrl+K",
        codeexample: "enter code here",

        image: "Image <img> Ctrl+G",
        imagedescription: "enter image description here",
        imagedialog: "<p><b>Insert Image</b></p><p>http://example.com/images/diagram.jpg \"optional title\"<br><br>Need <a href=''http://www.google.com/search?q=free+image+hosting'' target=''_blank''>free image hosting?</a></p>",

        olist: "Numbered List <ol> Ctrl+O",
        ulist: "Bulleted List <ul> Ctrl+U",
        litem: "List item",

        heading: "Heading <h1>/<h2> Ctrl+H",
        headingexample: "Heading",

        hr: "Horizontal Rule <hr> Ctrl+R",

        undo: "Undo - Ctrl+Z",
        redo: "Redo - Ctrl+Y",
        redomac: "Redo - Ctrl+Shift+Z",

        help: "Markdown Editing Help"
    };


    // -------------------------------------------------------------------
    //  YOUR CHANGES GO HERE
    //
    // I''ve tried to localize the things you are likely to change to
    // this area.
    // -------------------------------------------------------------------

    // The default text that appears in the dialog input box when entering
    // links.
    var imageDefaultText = "http://";
    var linkDefaultText = "http://";

    // -------------------------------------------------------------------
    //  END OF YOUR CHANGES
    // -------------------------------------------------------------------

    // options, if given, can have the following properties:
    //   options.helpButton = { handler: yourEventHandler }
    //   options.strings = { italicexample: "slanted text" }
    // `yourEventHandler` is the click handler for the help button.
    // If `options.helpButton` isn''t given, not help button is created.
    // `options.strings` can have any or all of the same properties as
    // `defaultStrings` above, so you can just override some string displayed
    // to the user on a case-by-case basis, or translate all strings to
    // a different language.
    //
    // For backwards compatibility reasons, the `options` argument can also
    // be just the `helpButton` object, and `strings.help` can also be set via
    // `helpButton.title`. This should be considered legacy.
    //
    // The constructed editor object has the methods:
    // - getConverter() returns the markdown converter object that was passed to the constructor
    // - run() actually starts the editor; should be called after all necessary plugins are registered. Calling this more than once is a no-op.
    // - refreshPreview() forces the preview to be updated. This method is only available after run() was called.
    Markdown.Editor = function (markdownConverter, idPostfix, options) {
        
        options = options || {};

        if (typeof options.handler === "function") { //backwards compatible behavior
            options = { helpButton: options };
        }
        options.strings = options.strings || {};
        if (options.helpButton) {
            options.strings.help = options.strings.help || options.helpButton.title;
        }
        var getString = function (identifier) { return options.strings[identifier] || defaultsStrings[identifier]; }

        idPostfix = idPostfix || "";

        var hooks = this.hooks = new Markdown.HookCollection();
        hooks.addNoop("onPreviewRefresh");       // called with no arguments after the preview has been refreshed
        hooks.addNoop("postBlockquoteCreation"); // called with the user''s selection *after* the blockquote was created; should return the actual to-be-inserted text
        hooks.addFalse("insertImageDialog");     /* called with one parameter: a callback to be called with the URL of the image. If the application creates
                                                  * its own image insertion dialog, this hook should return true, and the callback should be called with the chosen
                                                  * image url (or null if the user cancelled). If this hook returns false, the default dialog will be used.
                                                  */

        this.getConverter = function () { return markdownConverter; }

        var that = this,
            panels;

        this.run = function () {
            if (panels)
                return; // already initialized

            panels = new PanelCollection(idPostfix);
            var commandManager = new CommandManager(hooks, getString);
            var previewManager = new PreviewManager(markdownConverter, panels, function () { hooks.onPreviewRefresh(); });
            var undoManager, uiManager;

            if (!/\?noundo/.test(doc.location.href)) {
                undoManager = new UndoManager(function () {
                    previewManager.refresh();
                    if (uiManager) // not available on the first call
                        uiManager.setUndoRedoButtonStates();
                }, panels);
                this.textOperation = function (f) {
                    undoManager.setCommandMode();
                    f();
                    that.refreshPreview();
                }
            }

            uiManager = new UIManager(idPostfix, panels, undoManager, previewManager, commandManager, options.helpButton, getString);
            uiManager.setUndoRedoButtonStates();

            var forceRefresh = that.refreshPreview = function () { previewManager.refresh(true); };

            forceRefresh();
        };

    }

    // before: contains all the text in the input box BEFORE the selection.
    // after: contains all the text in the input box AFTER the selection.
    function Chunks() { }

    // startRegex: a regular expression to find the start tag
    // endRegex: a regular expresssion to find the end tag
    Chunks.prototype.findTags = function (startRegex, endRegex) {

        var chunkObj = this;
        var regex;

        if (startRegex) {

            regex = util.extendRegExp(startRegex, "", "$");

            this.before = this.before.replace(regex,
                function (match) {
                    chunkObj.startTag = chunkObj.startTag + match;
                    return "";
                });

            regex = util.extendRegExp(startRegex, "^", "");

            this.selection = this.selection.replace(regex,
                function (match) {
                    chunkObj.startTag = chunkObj.startTag + match;
                    return "";
                });
        }

        if (endRegex) {

            regex = util.extendRegExp(endRegex, "", "$");

            this.selection = this.selection.replace(regex,
                function (match) {
                    chunkObj.endTag = match + chunkObj.endTag;
                    return "";
                });

            regex = util.extendRegExp(endRegex, "^", "");

            this.after = this.after.replace(regex,
                function (match) {
                    chunkObj.endTag = match + chunkObj.endTag;
                    return "";
                });
        }
    };

    // If remove is false, the whitespace is transferred
    // to the before/after regions.
    //
    // If remove is true, the whitespace disappears.
    Chunks.prototype.trimWhitespace = function (remove) {
        var beforeReplacer, afterReplacer, that = this;
        if (remove) {
            beforeReplacer = afterReplacer = "";
        } else {
            beforeReplacer = function (s) { that.before += s; return ""; }
            afterReplacer = function (s) { that.after = s + that.after; return ""; }
        }

        this.selection = this.selection.replace(/^(\s*)/, beforeReplacer).replace(/(\s*)$/, afterReplacer);
    };


    Chunks.prototype.skipLines = function (nLinesBefore, nLinesAfter, findExtraNewlines) {

        if (nLinesBefore === undefined) {
            nLinesBefore = 1;
        }

        if (nLinesAfter === undefined) {
            nLinesAfter = 1;
        }

        nLinesBefore++;
        nLinesAfter++;

        var regexText;
        var replacementText;

        // chrome bug ... documented at: http://meta.stackoverflow.com/questions/63307/blockquote-glitch-in-editor-in-chrome-6-and-7/65985#65985
        if (navigator.userAgent.match(/Chrome/)) {
            "X".match(/()./);
        }

        this.selection = this.selection.replace(/(^\n*)/, "");

        this.startTag = this.startTag + re.$1;

        this.selection = this.selection.replace(/(\n*$)/, "");
        this.endTag = this.endTag + re.$1;
        this.startTag = this.startTag.replace(/(^\n*)/, "");
        this.before = this.before + re.$1;
        this.endTag = this.endTag.replace(/(\n*$)/, "");
        this.after = this.after + re.$1;

        if (this.before) {

            regexText = replacementText = "";

            while (nLinesBefore--) {
                regexText += "\\n?";
                replacementText += "\n";
            }

            if (findExtraNewlines) {
                regexText = "\\n*";
            }
            this.before = this.before.replace(new re(regexText + "$", ""), replacementText);
        }

        if (this.after) {

            regexText = replacementText = "";

            while (nLinesAfter--) {
                regexText += "\\n?";
                replacementText += "\n";
            }
            if (findExtraNewlines) {
                regexText = "\\n*";
            }

            this.after = this.after.replace(new re(regexText, ""), replacementText);
        }
    };

    // end of Chunks

    // A collection of the important regions on the page.
    // Cached so we don''t have to keep traversing the DOM.
    // Also holds ieCachedRange and ieCachedScrollTop, where necessary; working around
    // this issue:
    // Internet explorer has problems with CSS sprite buttons that use HTML
    // lists.  When you click on the background image "button", IE will
    // select the non-existent link text and discard the selection in the
    // textarea.  The solution to this is to cache the textarea selection
    // on the button''s mousedown event and set a flag.  In the part of the
    // code where we need to grab the selection, we check for the flag
    // and, if it''s set, use the cached area instead of querying the
    // textarea.
    //
    // This ONLY affects Internet Explorer (tested on versions 6, 7
    // and 8) and ONLY on button clicks.  Keyboard shortcuts work
    // normally since the focus never leaves the textarea.
    function PanelCollection(postfix) {
        this.buttonBar = doc.getElementById("wmd-button-bar" + postfix);
        this.preview = doc.getElementById("wmd-preview" + postfix);
        this.input = doc.getElementById("wmd-input" + postfix);
    };

    // Returns true if the DOM element is visible, false if it''s hidden.
    // Checks if display is anything other than none.
    util.isVisible = function (elem) {

        if (window.getComputedStyle) {
            // Most browsers
            return window.getComputedStyle(elem, null).getPropertyValue("display") !== "none";
        }
        else if (elem.currentStyle) {
            // IE
            return elem.currentStyle["display"] !== "none";
        }
    };


    // Adds a listener callback to a DOM element which is fired on a specified
    // event.
    util.addEvent = function (elem, event, listener) {
        if (elem.attachEvent) {
            // IE only.  The "on" is mandatory.
            elem.attachEvent("on" + event, listener);
        }
        else {
            // Other browsers.
            elem.addEventListener(event, listener, false);
        }
    };


    // Removes a listener callback from a DOM element which is fired on a specified
    // event.
    util.removeEvent = function (elem, event, listener) {
        if (elem.detachEvent) {
            // IE only.  The "on" is mandatory.
            elem.detachEvent("on" + event, listener);
        }
        else {
            // Other browsers.
            elem.removeEventListener(event, listener, false);
        }
    };

    // Converts \r\n and \r to \n.
    util.fixEolChars = function (text) {
        text = text.replace(/\r\n/g, "\n");
        text = text.replace(/\r/g, "\n");
        return text;
    };

    // Extends a regular expression.  Returns a new RegExp
    // using pre + regex + post as the expression.
    // Used in a few functions where we have a base
    // expression and we want to pre- or append some
    // conditions to it (e.g. adding "$" to the end).
    // The flags are unchanged.
    //
    // regex is a RegExp, pre and post are strings.
    util.extendRegExp = function (regex, pre, post) {

        if (pre === null || pre === undefined) {
            pre = "";
        }
        if (post === null || post === undefined) {
            post = "";
        }

        var pattern = regex.toString();
        var flags;

        // Replace the flags with empty space and store them.
        pattern = pattern.replace(/\/([gim]*)$/, function (wholeMatch, flagsPart) {
            flags = flagsPart;
            return "";
        });

        // Remove the slash delimiters on the regular expression.
        pattern = pattern.replace(/(^\/|\/$)/g, "");
        pattern = pre + pattern + post;

        return new re(pattern, flags);
    }

    // UNFINISHED
    // The assignment in the while loop makes jslint cranky.
    // I''ll change it to a better loop later.
    position.getTop = function (elem, isInner) {
        var result = elem.offsetTop;
        if (!isInner) {
            while (elem = elem.offsetParent) {
                result += elem.offsetTop;
            }
        }
        return result;
    };

    position.getHeight = function (elem) {
        return elem.offsetHeight || elem.scrollHeight;
    };

    position.getWidth = function (elem) {
        return elem.offsetWidth || elem.scrollWidth;
    };

    position.getPageSize = function () {

        var scrollWidth, scrollHeight;
        var innerWidth, innerHeight;

        // It''s not very clear which blocks work with which browsers.
        if (self.innerHeight && self.scrollMaxY) {
            scrollWidth = doc.body.scrollWidth;
            scrollHeight = self.innerHeight + self.scrollMaxY;
        }
        else if (doc.body.scrollHeight > doc.body.offsetHeight) {
            scrollWidth = doc.body.scrollWidth;
            scrollHeight = doc.body.scrollHeight;
        }
        else {
            scrollWidth = doc.body.offsetWidth;
            scrollHeight = doc.body.offsetHeight;
        }

        if (self.innerHeight) {
            // Non-IE browser
            innerWidth = self.innerWidth;
            innerHeight = self.innerHeight;
        }
        else if (doc.documentElement && doc.documentElement.clientHeight) {
            // Some versions of IE (IE 6 w/ a DOCTYPE declaration)
            innerWidth = doc.documentElement.clientWidth;
            innerHeight = doc.documentElement.clientHeight;
        }
        else if (doc.body) {
            // Other versions of IE
            innerWidth = doc.body.clientWidth;
            innerHeight = doc.body.clientHeight;
        }

        var maxWidth = Math.max(scrollWidth, innerWidth);
        var maxHeight = Math.max(scrollHeight, innerHeight);
        return [maxWidth, maxHeight, innerWidth, innerHeight];
    };

    // Handles pushing and popping TextareaStates for undo/redo commands.
    // I should rename the stack variables to list.
    function UndoManager(callback, panels) {

        var undoObj = this;
        var undoStack = []; // A stack of undo states
        var stackPtr = 0; // The index of the current state
        var mode = "none";
        var lastState; // The last state
        var timer; // The setTimeout handle for cancelling the timer
        var inputStateObj;

        // Set the mode for later logic steps.
        var setMode = function (newMode, noSave) {
            if (mode != newMode) {
                mode = newMode;
                if (!noSave) {
                    saveState();
                }
            }

            if (!uaSniffed.isIE || mode != "moving") {
                timer = setTimeout(refreshState, 1);
            }
            else {
                inputStateObj = null;
            }
        };

        var refreshState = function (isInitialState) {
            inputStateObj = new TextareaState(panels, isInitialState);
            timer = undefined;
        };

        this.setCommandMode = function () {
            mode = "command";
            saveState();
            timer = setTimeout(refreshState, 0);
        };

        this.canUndo = function () {
            return stackPtr > 1;
        };

        this.canRedo = function () {
            if (undoStack[stackPtr + 1]) {
                return true;
            }
            return false;
        };

        // Removes the last state and restores it.
        this.undo = function () {

            if (undoObj.canUndo()) {
                if (lastState) {
                    // What about setting state -1 to null or checking for undefined?
                    lastState.restore();
                    lastState = null;
                }
                else {
                    undoStack[stackPtr] = new TextareaState(panels);
                    undoStack[--stackPtr].restore();

                    if (callback) {
                        callback();
                    }
                }
            }

            mode = "none";
            panels.input.focus();
            refreshState();
        };

        // Redo an action.
        this.redo = function () {

            if (undoObj.canRedo()) {

                undoStack[++stackPtr].restore();

                if (callback) {
                    callback();
                }
            }

            mode = "none";
            panels.input.focus();
            refreshState();
        };

        // Push the input area state to the stack.
        var saveState = function () {
            var currState = inputStateObj || new TextareaState(panels);

            if (!currState) {
                return false;
            }
            if (mode == "moving") {
                if (!lastState) {
                    lastState = currState;
                }
                return;
            }
            if (lastState) {
                if (undoStack[stackPtr - 1].text != lastState.text) {
                    undoStack[stackPtr++] = lastState;
                }
                lastState = null;
            }
            undoStack[stackPtr++] = currState;
            undoStack[stackPtr + 1] = null;
            if (callback) {
                callback();
            }
        };

        var handleCtrlYZ = function (event) {

            var handled = false;

            if (event.ctrlKey || event.metaKey) {

                // IE and Opera do not support charCode.
                var keyCode = event.charCode || event.keyCode;
                var keyCodeChar = String.fromCharCode(keyCode);

                switch (keyCodeChar.toLowerCase()) {

                    case "y":
                        undoObj.redo();
                        handled = true;
                        break;

                    case "z":
                        if (!event.shiftKey) {
                            undoObj.undo();
                        }
                        else {
                            undoObj.redo();
                        }
                        handled = true;
                        break;
                }
            }

            if (handled) {
                if (event.preventDefault) {
                    event.preventDefault();
                }
                if (window.event) {
                    window.event.returnValue = false;
                }
                return;
            }
        };

        // Set the mode depending on what is going on in the input area.
        var handleModeChange = function (event) {

            if (!event.ctrlKey && !event.metaKey) {

                var keyCode = event.keyCode;

                if ((keyCode >= 33 && keyCode <= 40) || (keyCode >= 63232 && keyCode <= 63235)) {
                    // 33 - 40: page up/dn and arrow keys
                    // 63232 - 63235: page up/dn and arrow keys on safari
                    setMode("moving");
                }
                else if (keyCode == 8 || keyCode == 46 || keyCode == 127) {
                    // 8: backspace
                    // 46: delete
                    // 127: delete
                    setMode("deleting");
                }
                else if (keyCode == 13) {
                    // 13: Enter
                    setMode("newlines");
                }
                else if (keyCode == 27) {
                    // 27: escape
                    setMode("escape");
                }
                else if ((keyCode < 16 || keyCode > 20) && keyCode != 91) {
                    // 16-20 are shift, etc.
                    // 91: left window key
                    // I think this might be a little messed up since there are
                    // a lot of nonprinting keys above 20.
                    setMode("typing");
                }
            }
        };

        var setEventHandlers = function () {
            util.addEvent(panels.input, "keypress", function (event) {
                // keyCode 89: y
                // keyCode 90: z
                if ((event.ctrlKey || event.metaKey) && (event.keyCode == 89 || event.keyCode == 90)) {
                    event.preventDefault();
                }
            });

            var handlePaste = function () {
                if (uaSniffed.isIE || (inputStateObj && inputStateObj.text != panels.input.value)) {
                    if (timer == undefined) {
                        mode = "paste";
                        saveState();
                        refreshState();
                    }
                }
            };

            util.addEvent(panels.input, "keydown", handleCtrlYZ);
            util.addEvent(panels.input, "keydown", handleModeChange);
            util.addEvent(panels.input, "mousedown", function () {
                setMode("moving");
            });

            panels.input.onpaste = handlePaste;
            panels.input.ondrop = handlePaste;
        };

        var init = function () {
            setEventHandlers();
            refreshState(true);
            saveState();
        };

        init();
    }

    // end of UndoManager

    // The input textarea state/contents.
    // This is used to implement undo/redo by the undo manager.
    function TextareaState(panels, isInitialState) {

        // Aliases
        var stateObj = this;
        var inputArea = panels.input;
        this.init = function () {
            if (!util.isVisible(inputArea)) {
                return;
            }
            if (!isInitialState && doc.activeElement && doc.activeElement !== inputArea) { // this happens when tabbing out of the input box
                return;
            }

            this.setInputAreaSelectionStartEnd();
            this.scrollTop = inputArea.scrollTop;
            if (!this.text && inputArea.selectionStart || inputArea.selectionStart === 0) {
                this.text = inputArea.value;
            }

        }

        // Sets the selected text in the input box after we''ve performed an
        // operation.
        this.setInputAreaSelection = function () {

            if (!util.isVisible(inputArea)) {
                return;
            }

            if (inputArea.selectionStart !== undefined && !uaSniffed.isOpera) {

                inputArea.focus();
                inputArea.selectionStart = stateObj.start;
                inputArea.selectionEnd = stateObj.end;
                inputArea.scrollTop = stateObj.scrollTop;
            }
            else if (doc.selection) {

                if (doc.activeElement && doc.activeElement !== inputArea) {
                    return;
                }

                inputArea.focus();
                var range = inputArea.createTextRange();
                range.moveStart("character", -inputArea.value.length);
                range.moveEnd("character", -inputArea.value.length);
                range.moveEnd("character", stateObj.end);
                range.moveStart("character", stateObj.start);
                range.select();
            }
        };

        this.setInputAreaSelectionStartEnd = function () {

            if (!panels.ieCachedRange && (inputArea.selectionStart || inputArea.selectionStart === 0)) {

                stateObj.start = inputArea.selectionStart;
                stateObj.end = inputArea.selectionEnd;
            }
            else if (doc.selection) {

                stateObj.text = util.fixEolChars(inputArea.value);

                // IE loses the selection in the textarea when buttons are
                // clicked.  On IE we cache the selection. Here, if something is cached,
                // we take it.
                var range = panels.ieCachedRange || doc.selection.createRange();

                var fixedRange = util.fixEolChars(range.text);
                var marker = "\x07";
                var markedRange = marker + fixedRange + marker;
                range.text = markedRange;
                var inputText = util.fixEolChars(inputArea.value);

                range.moveStart("character", -markedRange.length);
                range.text = fixedRange;

                stateObj.start = inputText.indexOf(marker);
                stateObj.end = inputText.lastIndexOf(marker) - marker.length;

                var len = stateObj.text.length - util.fixEolChars(inputArea.value).length;

                if (len) {
                    range.moveStart("character", -fixedRange.length);
                    while (len--) {
                        fixedRange += "\n";
                        stateObj.end += 1;
                    }
                    range.text = fixedRange;
                }

                if (panels.ieCachedRange)
                    stateObj.scrollTop = panels.ieCachedScrollTop; // this is set alongside with ieCachedRange

                panels.ieCachedRange = null;

                this.setInputAreaSelection();
            }
        };

        // Restore this state into the input area.
        this.restore = function () {

            if (stateObj.text != undefined && stateObj.text != inputArea.value) {
                inputArea.value = stateObj.text;
            }
            this.setInputAreaSelection();
            inputArea.scrollTop = stateObj.scrollTop;
        };

        // Gets a collection of HTML chunks from the inptut textarea.
        this.getChunks = function () {

            var chunk = new Chunks();
            chunk.before = util.fixEolChars(stateObj.text.substring(0, stateObj.start));
            chunk.startTag = "";
            chunk.selection = util.fixEolChars(stateObj.text.substring(stateObj.start, stateObj.end));
            chunk.endTag = "";
            chunk.after = util.fixEolChars(stateObj.text.substring(stateObj.end));
            chunk.scrollTop = stateObj.scrollTop;

            return chunk;
        };

        // Sets the TextareaState properties given a chunk of markdown.
        this.setChunks = function (chunk) {

            chunk.before = chunk.before + chunk.startTag;
            chunk.after = chunk.endTag + chunk.after;

            this.start = chunk.before.length;
            this.end = chunk.before.length + chunk.selection.length;
            this.text = chunk.before + chunk.selection + chunk.after;
            this.scrollTop = chunk.scrollTop;
        };
        this.init();
    };

    function PreviewManager(converter, panels, previewRefreshCallback) {

        var managerObj = this;
        var timeout;
        var elapsedTime;
        var oldInputText;
        var maxDelay = 3000;
        var startType = "delayed"; // The other legal value is "manual"

        // Adds event listeners to elements
        var setupEvents = function (inputElem, listener) {

            util.addEvent(inputElem, "input", listener);
            inputElem.onpaste = listener;
            inputElem.ondrop = listener;

            util.addEvent(inputElem, "keypress", listener);
            util.addEvent(inputElem, "keydown", listener);
        };

        var getDocScrollTop = function () {

            var result = 0;

            if (window.innerHeight) {
                result = window.pageYOffset;
            }
            else
                if (doc.documentElement && doc.documentElement.scrollTop) {
                    result = doc.documentElement.scrollTop;
                }
                else
                    if (doc.body) {
                        result = doc.body.scrollTop;
                    }

            return result;
        };

        var makePreviewHtml = function () {

            // If there is no registered preview panel
            // there is nothing to do.
            if (!panels.preview)
                return;


            var text = panels.input.value;
            if (text && text == oldInputText) {
                return; // Input text hasn''t changed.
            }
            else {
                oldInputText = text;
            }

            var prevTime = new Date().getTime();

            text = converter.makeHtml(text);

            // Calculate the processing time of the HTML creation.
            // It''s used as the delay time in the event listener.
            var currTime = new Date().getTime();
            elapsedTime = currTime - prevTime;

            pushPreviewHtml(text);
        };

        // setTimeout is already used.  Used as an event listener.
        var applyTimeout = function () {

            if (timeout) {
                clearTimeout(timeout);
                timeout = undefined;
            }

            if (startType !== "manual") {

                var delay = 0;

                if (startType === "delayed") {
                    delay = elapsedTime;
                }

                if (delay > maxDelay) {
                    delay = maxDelay;
                }
                timeout = setTimeout(makePreviewHtml, delay);
            }
        };

        var getScaleFactor = function (panel) {
            if (panel.scrollHeight <= panel.clientHeight) {
                return 1;
            }
            return panel.scrollTop / (panel.scrollHeight - panel.clientHeight);
        };

        var setPanelScrollTops = function () {
            if (panels.preview) {
                panels.preview.scrollTop = (panels.preview.scrollHeight - panels.preview.clientHeight) * getScaleFactor(panels.preview);
            }
        };

        this.refresh = function (requiresRefresh) {

            if (requiresRefresh) {
                oldInputText = "";
                makePreviewHtml();
            }
            else {
                applyTimeout();
            }
        };

        this.processingTime = function () {
            return elapsedTime;
        };

        var isFirstTimeFilled = true;

        // IE doesn''t let you use innerHTML if the element is contained somewhere in a table
        // (which is the case for inline editing) -- in that case, detach the element, set the
        // value, and reattach. Yes, that *is* ridiculous.
        var ieSafePreviewSet = function (text) {
            var preview = panels.preview;
            var parent = preview.parentNode;
            var sibling = preview.nextSibling;
            parent.removeChild(preview);
            preview.innerHTML = text;
            if (!sibling)
                parent.appendChild(preview);
            else
                parent.insertBefore(preview, sibling);
        }

        var nonSuckyBrowserPreviewSet = function (text) {
            panels.preview.innerHTML = text;
        }

        var previewSetter;

        var previewSet = function (text) {
            if (previewSetter)
                return previewSetter(text);

            try {
                nonSuckyBrowserPreviewSet(text);
                previewSetter = nonSuckyBrowserPreviewSet;
            } catch (e) {
                previewSetter = ieSafePreviewSet;
                previewSetter(text);
            }
        };

        var pushPreviewHtml = function (text) {

            var emptyTop = position.getTop(panels.input) - getDocScrollTop();

            if (panels.preview) {
                previewSet(text);
                previewRefreshCallback();
            }

            setPanelScrollTops();

            if (isFirstTimeFilled) {
                isFirstTimeFilled = false;
                return;
            }

            var fullTop = position.getTop(panels.input) - getDocScrollTop();

            if (uaSniffed.isIE) {
                setTimeout(function () {
                    window.scrollBy(0, fullTop - emptyTop);
                }, 0);
            }
            else {
                window.scrollBy(0, fullTop - emptyTop);
            }
        };

        var init = function () {

            setupEvents(panels.input, applyTimeout);
            makePreviewHtml();

            if (panels.preview) {
                panels.preview.scrollTop = 0;
            }
        };

        init();
    };

    // Creates the background behind the hyperlink text entry box.
    // And download dialog
    // Most of this has been moved to CSS but the div creation and
    // browser-specific hacks remain here.
    ui.createBackground = function () {

        var background = doc.createElement("div"),
            style = background.style;
        
        background.className = "wmd-prompt-background";
        
        style.position = "absolute";
        style.top = "0";

        style.zIndex = "1000";

        if (uaSniffed.isIE) {
            style.filter = "alpha(opacity=50)";
        }
        else {
            style.opacity = "0.5";
        }

        var pageSize = position.getPageSize();
        style.height = pageSize[1] + "px";

        if (uaSniffed.isIE) {
            style.left = doc.documentElement.scrollLeft;
            style.width = doc.documentElement.clientWidth;
        }
        else {
            style.left = "0";
            style.width = "100%";
        }

        doc.body.appendChild(background);
        return background;
    };

    // This simulates a modal dialog box and asks for the URL when you
    // click the hyperlink or image buttons.
    //
    // text: The html for the input box.
    // defaultInputText: The default value that appears in the input box.
    // callback: The function which is executed when the prompt is dismissed, either via OK or Cancel.
    //      It receives a single argument; either the entered text (if OK was chosen) or null (if Cancel
    //      was chosen).
    ui.prompt = function (text, defaultInputText, callback) {

        // These variables need to be declared at this level since they are used
        // in multiple functions.
        var dialog;         // The dialog box.
        var input;         // The text box where you enter the hyperlink.


        if (defaultInputText === undefined) {
            defaultInputText = "";
        }

        // Used as a keydown event handler. Esc dismisses the prompt.
        // Key code 27 is ESC.
        var checkEscape = function (key) {
            var code = (key.charCode || key.keyCode);
            if (code === 27) {
                close(true);
            }
        };

        // Dismisses the hyperlink input box.
        // isCancel is true if we don''t care about the input text.
        // isCancel is false if we are going to keep the text.
        var close = function (isCancel) {
            util.removeEvent(doc.body, "keydown", checkEscape);
            var text = input.value;

            if (isCancel) {
                text = null;
            }
            else {
                // Fixes common pasting errors.
                text = text.replace(/^http:\/\/(https?|ftp):\/\//, ''$1://'');
                if (!/^(?:https?|ftp):\/\//.test(text))
                    text = ''http://'' + text;
            }

            dialog.parentNode.removeChild(dialog);

            callback(text);
            return false;
        };



        // Create the text input box form/window.
        var createDialog = function () {

            // The main dialog box.
            dialog = doc.createElement("div");
            dialog.className = "wmd-prompt-dialog";
            dialog.style.padding = "10px;";
            dialog.style.position = "fixed";
            dialog.style.width = "400px";
            dialog.style.zIndex = "1001";

            // The dialog text.
            var question = doc.createElement("div");
            question.innerHTML = text;
            question.style.padding = "5px";
            dialog.appendChild(question);

            // The web form container for the text box and buttons.
            var form = doc.createElement("form"),
                style = form.style;
            form.onsubmit = function () { return close(false); };
            style.padding = "0";
            style.margin = "0";
            style.cssFloat = "left";
            style.width = "100%";
            style.textAlign = "center";
            style.position = "relative";
            dialog.appendChild(form);

            // The input text box
            input = doc.createElement("input");
            input.type = "text";
            input.value = defaultInputText;
            style = input.style;
            style.display = "block";
            style.width = "80%";
            style.marginLeft = style.marginRight = "auto";
            form.appendChild(input);

            // The ok button
            var okButton = doc.createElement("input");
            okButton.type = "button";
            okButton.onclick = function () { return close(false); };
            okButton.value = "OK";
            style = okButton.style;
            style.margin = "10px";
            style.display = "inline";
            style.width = "7em";


            // The cancel button
            var cancelButton = doc.createElement("input");
            cancelButton.type = "button";
            cancelButton.onclick = function () { return close(true); };
            cancelButton.value = "Cancel";
            style = cancelButton.style;
            style.margin = "10px";
            style.display = "inline";
            style.width = "7em";

            form.appendChild(okButton);
            form.appendChild(cancelButton);

            util.addEvent(doc.body, "keydown", checkEscape);
            dialog.style.top = "50%";
            dialog.style.left = "50%";
            dialog.style.display = "block";
            if (uaSniffed.isIE_5or6) {
                dialog.style.position = "absolute";
                dialog.style.top = doc.documentElement.scrollTop + 200 + "px";
                dialog.style.left = "50%";
            }
            doc.body.appendChild(dialog);

            // This has to be done AFTER adding the dialog to the form if you
            // want it to be centered.
            dialog.style.marginTop = -(position.getHeight(dialog) / 2) + "px";
            dialog.style.marginLeft = -(position.getWidth(dialog) / 2) + "px";

        };

        // Why is this in a zero-length timeout?
        // Is it working around a browser bug?
        setTimeout(function () {

            createDialog();

            var defTextLen = defaultInputText.length;
            if (input.selectionStart !== undefined) {
                input.selectionStart = 0;
                input.selectionEnd = defTextLen;
            }
            else if (input.createTextRange) {
                var range = input.createTextRange();
                range.collapse(false);
                range.moveStart("character", -defTextLen);
                range.moveEnd("character", defTextLen);
                range.select();
            }

            input.focus();
        }, 0);
    };

    function UIManager(postfix, panels, undoManager, previewManager, commandManager, helpOptions, getString) {

        var inputBox = panels.input,
            buttons = {}; // buttons.undo, buttons.link, etc. The actual DOM elements.

        makeSpritedButtonRow();

        var keyEvent = "keydown";
        if (uaSniffed.isOpera) {
            keyEvent = "keypress";
        }

        util.addEvent(inputBox, keyEvent, function (key) {

            // Check to see if we have a button key and, if so execute the callback.
            if ((key.ctrlKey || key.metaKey) && !key.altKey && !key.shiftKey) {

                var keyCode = key.charCode || key.keyCode;
                var keyCodeStr = String.fromCharCode(keyCode).toLowerCase();

                switch (keyCodeStr) {
                    case "b":
                        doClick(buttons.bold);
                        break;
                    case "i":
                        doClick(buttons.italic);
                        break;
                    case "l":
                        doClick(buttons.link);
                        break;
                    case "q":
                        doClick(buttons.quote);
                        break;
                    case "k":
                        doClick(buttons.code);
                        break;
                    case "g":
                        doClick(buttons.image);
                        break;
                    case "o":
                        doClick(buttons.olist);
                        break;
                    case "u":
                        doClick(buttons.ulist);
                        break;
                    case "h":
                        doClick(buttons.heading);
                        break;
                    case "r":
                        doClick(buttons.hr);
                        break;
                    case "y":
                        doClick(buttons.redo);
                        break;
                    case "z":
                        if (key.shiftKey) {
                            doClick(buttons.redo);
                        }
                        else {
                            doClick(buttons.undo);
                        }
                        break;
                    default:
                        return;
                }


                if (key.preventDefault) {
                    key.preventDefault();
                }

                if (window.event) {
                    window.event.returnValue = false;
                }
            }
        });

        // Auto-indent on shift-enter
        util.addEvent(inputBox, "keyup", function (key) {
            if (key.shiftKey && !key.ctrlKey && !key.metaKey) {
                var keyCode = key.charCode || key.keyCode;
                // Character 13 is Enter
                if (keyCode === 13) {
                    var fakeButton = {};
                    fakeButton.textOp = bindCommand("doAutoindent");
                    doClick(fakeButton);
                }
            }
        });

        // special handler because IE clears the context of the textbox on ESC
        if (uaSniffed.isIE) {
            util.addEvent(inputBox, "keydown", function (key) {
                var code = key.keyCode;
                if (code === 27) {
                    return false;
                }
            });
        }


        // Perform the button''s action.
        function doClick(button) {

            inputBox.focus();

            if (button.textOp) {

                if (undoManager) {
                    undoManager.setCommandMode();
                }

                var state = new TextareaState(panels);

                if (!state) {
                    return;
                }

                var chunks = state.getChunks();

                // Some commands launch a "modal" prompt dialog.  Javascript
                // can''t really make a modal dialog box and the WMD code
                // will continue to execute while the dialog is displayed.
                // This prevents the dialog pattern I''m used to and means
                // I can''t do something like this:
                //
                // var link = CreateLinkDialog();
                // makeMarkdownLink(link);
                //
                // Instead of this straightforward method of handling a
                // dialog I have to pass any code which would execute
                // after the dialog is dismissed (e.g. link creation)
                // in a function parameter.
                //
                // Yes this is awkward and I think it sucks, but there''s
                // no real workaround.  Only the image and link code
                // create dialogs and require the function pointers.
                var fixupInputArea = function () {

                    inputBox.focus();

                    if (chunks) {
                        state.setChunks(chunks);
                    }

                    state.restore();
                    previewManager.refresh();
                };

                var noCleanup = button.textOp(chunks, fixupInputArea);

                if (!noCleanup) {
                    fixupInputArea();
                }

            }

            if (button.execute) {
                button.execute(undoManager);
            }
        };

        function setupButton(button, isEnabled) {

            var normalYShift = "0px";
            var disabledYShift = "-20px";
            var highlightYShift = "-40px";
            var image = button.getElementsByTagName("span")[0];
            if (isEnabled) {
                image.style.backgroundPosition = button.XShift + " " + normalYShift;
                button.onmouseover = function () {
                    image.style.backgroundPosition = this.XShift + " " + highlightYShift;
                };

                button.onmouseout = function () {
                    image.style.backgroundPosition = this.XShift + " " + normalYShift;
                };

                // IE tries to select the background image "button" text (it''s
                // implemented in a list item) so we have to cache the selection
                // on mousedown.
                if (uaSniffed.isIE) {
                    button.onmousedown = function () {
                        if (doc.activeElement && doc.activeElement !== panels.input) { // we''re not even in the input box, so there''s no selection
                            return;
                        }
                        panels.ieCachedRange = document.selection.createRange();
                        panels.ieCachedScrollTop = panels.input.scrollTop;
                    };
                }

                if (!button.isHelp) {
                    button.onclick = function () {
                        if (this.onmouseout) {
                            this.onmouseout();
                        }
                        doClick(this);
                        return false;
                    }
                }
            }
            else {
                image.style.backgroundPosition = button.XShift + " " + disabledYShift;
                button.onmouseover = button.onmouseout = button.onclick = function () { };
            }
        }

        function bindCommand(method) {
            if (typeof method === "string")
                method = commandManager[method];
            return function () { method.apply(commandManager, arguments); }
        }

        function makeSpritedButtonRow() {

            var buttonBar = panels.buttonBar;

            var normalYShift = "0px";
            var disabledYShift = "-20px";
            var highlightYShift = "-40px";

            var buttonRow = document.createElement("ul");
            buttonRow.id = "wmd-button-row" + postfix;
            buttonRow.className = ''wmd-button-row'';
            buttonRow = buttonBar.appendChild(buttonRow);
            var xPosition = 0;
            var makeButton = function (id, title, XShift, textOp) {
                var button = document.createElement("li");
                button.className = "wmd-button";
                button.style.left = xPosition + "px";
                xPosition += 25;
                var buttonImage = document.createElement("span");
                button.id = id + postfix;
                button.appendChild(buttonImage);
                button.title = title;
                button.XShift = XShift;
                if (textOp)
                    button.textOp = textOp;
                setupButton(button, true);
                buttonRow.appendChild(button);
                return button;
            };
            var makeSpacer = function (num) {
                var spacer = document.createElement("li");
                spacer.className = "wmd-spacer wmd-spacer" + num;
                spacer.id = "wmd-spacer" + num + postfix;
                buttonRow.appendChild(spacer);
                xPosition += 25;
            }

            buttons.bold = makeButton("wmd-bold-button", getString("bold"), "0px", bindCommand("doBold"));
            buttons.italic = makeButton("wmd-italic-button", getString("italic"), "-20px", bindCommand("doItalic"));
            makeSpacer(1);
            buttons.link = makeButton("wmd-link-button", getString("link"), "-40px", bindCommand(function (chunk, postProcessing) {
                return this.doLinkOrImage(chunk, postProcessing, false);
            }));
            buttons.quote = makeButton("wmd-quote-button", getString("quote"), "-60px", bindCommand("doBlockquote"));
            buttons.code = makeButton("wmd-code-button", getString("code"), "-80px", bindCommand("doCode"));
            buttons.image = makeButton("wmd-image-button", getString("image"), "-100px", bindCommand(function (chunk, postProcessing) {
                return this.doLinkOrImage(chunk, postProcessing, true);
            }));
            makeSpacer(2);
            buttons.olist = makeButton("wmd-olist-button", getString("olist"), "-120px", bindCommand(function (chunk, postProcessing) {
                this.doList(chunk, postProcessing, true);
            }));
            buttons.ulist = makeButton("wmd-ulist-button", getString("ulist"), "-140px", bindCommand(function (chunk, postProcessing) {
                this.doList(chunk, postProcessing, false);
            }));
            buttons.heading = makeButton("wmd-heading-button", getString("heading"), "-160px", bindCommand("doHeading"));
            buttons.hr = makeButton("wmd-hr-button", getString("hr"), "-180px", bindCommand("doHorizontalRule"));
            makeSpacer(3);
            buttons.undo = makeButton("wmd-undo-button", getString("undo"), "-200px", null);
            buttons.undo.execute = function (manager) { if (manager) manager.undo(); };

            var redoTitle = /win/.test(nav.platform.toLowerCase()) ?
                getString("redo") :
                getString("redomac"); // mac and other non-Windows platforms

            buttons.redo = makeButton("wmd-redo-button", redoTitle, "-220px", null);
            buttons.redo.execute = function (manager) { if (manager) manager.redo(); };

            if (helpOptions) {
                var helpButton = document.createElement("li");
                var helpButtonImage = document.createElement("span");
                helpButton.appendChild(helpButtonImage);
                helpButton.className = "wmd-button wmd-help-button";
                helpButton.id = "wmd-help-button" + postfix;
                helpButton.XShift = "-240px";
                helpButton.isHelp = true;
                helpButton.style.right = "0px";
                helpButton.title = getString("help");
                helpButton.onclick = helpOptions.handler;

                setupButton(helpButton, true);
                buttonRow.appendChild(helpButton);
                buttons.help = helpButton;
            }

            setUndoRedoButtonStates();
        }

        function setUndoRedoButtonStates() {
            if (undoManager) {
                setupButton(buttons.undo, undoManager.canUndo());
                setupButton(buttons.redo, undoManager.canRedo());
            }
        };

        this.setUndoRedoButtonStates = setUndoRedoButtonStates;

    }

    function CommandManager(pluginHooks, getString) {
        this.hooks = pluginHooks;
        this.getString = getString;
    }

    var commandProto = CommandManager.prototype;

    // The markdown symbols - 4 spaces = code, > = blockquote, etc.
    commandProto.prefixes = "(?:\\s{4,}|\\s*>|\\s*-\\s+|\\s*\\d+\\.|=|\\+|-|_|\\*|#|\\s*\\[[^\n]]+\\]:)";

    // Remove markdown symbols from the chunk selection.
    commandProto.unwrap = function (chunk) {
        var txt = new re("([^\\n])\\n(?!(\\n|" + this.prefixes + "))", "g");
        chunk.selection = chunk.selection.replace(txt, "$1 $2");
    };

    commandProto.wrap = function (chunk, len) {
        this.unwrap(chunk);
        var regex = new re("(.{1," + len + "})( +|$\\n?)", "gm"),
            that = this;

        chunk.selection = chunk.selection.replace(regex, function (line, marked) {
            if (new re("^" + that.prefixes, "").test(line)) {
                return line;
            }
            return marked + "\n";
        });

        chunk.selection = chunk.selection.replace(/\s+$/, "");
    };

    commandProto.doBold = function (chunk, postProcessing) {
        return this.doBorI(chunk, postProcessing, 2, this.getString("boldexample"));
    };

    commandProto.doItalic = function (chunk, postProcessing) {
        return this.doBorI(chunk, postProcessing, 1, this.getString("italicexample"));
    };

    // chunk: The selected region that will be enclosed with */**
    // nStars: 1 for italics, 2 for bold
    // insertText: If you just click the button without highlighting text, this gets inserted
    commandProto.doBorI = function (chunk, postProcessing, nStars, insertText) {

        // Get rid of whitespace and fixup newlines.
        chunk.trimWhitespace();
        chunk.selection = chunk.selection.replace(/\n{2,}/g, "\n");

        // Look for stars before and after.  Is the chunk already marked up?
        // note that these regex matches cannot fail
        var starsBefore = /(\**$)/.exec(chunk.before)[0];
        var starsAfter = /(^\**)/.exec(chunk.after)[0];

        var prevStars = Math.min(starsBefore.length, starsAfter.length);

        // Remove stars if we have to since the button acts as a toggle.
        if ((prevStars >= nStars) && (prevStars != 2 || nStars != 1)) {
            chunk.before = chunk.before.replace(re("[*]{" + nStars + "}$", ""), "");
            chunk.after = chunk.after.replace(re("^[*]{" + nStars + "}", ""), "");
        }
        else if (!chunk.selection && starsAfter) {
            // It''s not really clear why this code is necessary.  It just moves
            // some arbitrary stuff around.
            chunk.after = chunk.after.replace(/^([*_]*)/, "");
            chunk.before = chunk.before.replace(/(\s?)$/, "");
            var whitespace = re.$1;
            chunk.before = chunk.before + starsAfter + whitespace;
        }
        else {

            // In most cases, if you don''t have any selected text and click the button
            // you''ll get a selected, marked up region with the default text inserted.
            if (!chunk.selection && !starsAfter) {
                chunk.selection = insertText;
            }

            // Add the true markup.
            var markup = nStars <= 1 ? "*" : "**"; // shouldn''t the test be = ?
            chunk.before = chunk.before + markup;
            chunk.after = markup + chunk.after;
        }

        return;
    };

    commandProto.stripLinkDefs = function (text, defsToAdd) {

        text = text.replace(/^[ ]{0,3}\[(\d+)\]:[ \t]*\n?[ \t]*<?(\S+?)>?[ \t]*\n?[ \t]*(?:(\n*)["(](.+?)[")][ \t]*)?(?:\n+|$)/gm,
            function (totalMatch, id, link, newlines, title) {
                defsToAdd[id] = totalMatch.replace(/\s*$/, "");
                if (newlines) {
                    // Strip the title and return that separately.
                    defsToAdd[id] = totalMatch.replace(/["(](.+?)[")]$/, "");
                    return newlines + title;
                }
                return "";
            });

        return text;
    };

    commandProto.addLinkDef = function (chunk, linkDef) {

        var refNumber = 0; // The current reference number
        var defsToAdd = {}; //
        // Start with a clean slate by removing all previous link definitions.
        chunk.before = this.stripLinkDefs(chunk.before, defsToAdd);
        chunk.selection = this.stripLinkDefs(chunk.selection, defsToAdd);
        chunk.after = this.stripLinkDefs(chunk.after, defsToAdd);

        var defs = "";
        var regex = /(\[)((?:\[[^\]]*\]|[^\[\]])*)(\][ ]?(?:\n[ ]*)?\[)(\d+)(\])/g;

        var addDefNumber = function (def) {
            refNumber++;
            def = def.replace(/^[ ]{0,3}\[(\d+)\]:/, "  [" + refNumber + "]:");
            defs += "\n" + def;
        };

        // note that
        // a) the recursive call to getLink cannot go infinite, because by definition
        //    of regex, inner is always a proper substring of wholeMatch, and
        // b) more than one level of nesting is neither supported by the regex
        //    nor making a lot of sense (the only use case for nesting is a linked image)
        var getLink = function (wholeMatch, before, inner, afterInner, id, end) {
            inner = inner.replace(regex, getLink);
            if (defsToAdd[id]) {
                addDefNumber(defsToAdd[id]);
                return before + inner + afterInner + refNumber + end;
            }
            return wholeMatch;
        };

        chunk.before = chunk.before.replace(regex, getLink);

        if (linkDef) {
            addDefNumber(linkDef);
        }
        else {
            chunk.selection = chunk.selection.replace(regex, getLink);
        }

        var refOut = refNumber;

        chunk.after = chunk.after.replace(regex, getLink);

        if (chunk.after) {
            chunk.after = chunk.after.replace(/\n*$/, "");
        }
        if (!chunk.after) {
            chunk.selection = chunk.selection.replace(/\n*$/, "");
        }

        chunk.after += "\n\n" + defs;

        return refOut;
    };

    // takes the line as entered into the add link/as image dialog and makes
    // sure the URL and the optinal title are "nice".
    function properlyEncoded(linkdef) {
        return linkdef.replace(/^\s*(.*?)(?:\s+"(.+)")?\s*$/, function (wholematch, link, title) {
            link = link.replace(/\?.*$/, function (querypart) {
                return querypart.replace(/\+/g, " "); // in the query string, a plus and a space are identical
            });
            link = decodeURIComponent(link); // unencode first, to prevent double encoding
            link = encodeURI(link).replace(/''/g, ''%27'').replace(/\(/g, ''%28'').replace(/\)/g, ''%29'');
            link = link.replace(/\?.*$/, function (querypart) {
                return querypart.replace(/\+/g, "%2b"); // since we replaced plus with spaces in the query part, all pluses that now appear where originally encoded
            });
            if (title) {
                title = title.trim ? title.trim() : title.replace(/^\s*/, "").replace(/\s*$/, "");
                title = title.replace(/"/g, "quot;").replace(/\(/g, "&#40;").replace(/\)/g, "&#41;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
            }
            return title ? link + '' "'' + title + ''"'' : link;
        });
    }

    commandProto.doLinkOrImage = function (chunk, postProcessing, isImage) {

        chunk.trimWhitespace();
        chunk.findTags(/\s*!?\[/, /\][ ]?(?:\n[ ]*)?(\[.*?\])?/);
        var background;

        if (chunk.endTag.length > 1 && chunk.startTag.length > 0) {

            chunk.startTag = chunk.startTag.replace(/!?\[/, "");
            chunk.endTag = "";
            this.addLinkDef(chunk, null);

        }
        else {
            
            // We''re moving start and end tag back into the selection, since (as we''re in the else block) we''re not
            // *removing* a link, but *adding* one, so whatever findTags() found is now back to being part of the
            // link text. linkEnteredCallback takes care of escaping any brackets.
            chunk.selection = chunk.startTag + chunk.selection + chunk.endTag;
            chunk.startTag = chunk.endTag = "";

            if (/\n\n/.test(chunk.selection)) {
                this.addLinkDef(chunk, null);
                return;
            }
            var that = this;
            // The function to be executed when you enter a link and press OK or Cancel.
            // Marks up the link and adds the ref.
            var linkEnteredCallback = function (link) {

                background.parentNode.removeChild(background);

                if (link !== null) {
                    // (                          $1
                    //     [^\\]                  anything that''s not a backslash
                    //     (?:\\\\)*              an even number (this includes zero) of backslashes
                    // )
                    // (?=                        followed by
                    //     [[\]]                  an opening or closing bracket
                    // )
                    //
                    // In other words, a non-escaped bracket. These have to be escaped now to make sure they
                    // don''t count as the end of the link or similar.
                    // Note that the actual bracket has to be a lookahead, because (in case of to subsequent brackets),
                    // the bracket in one match may be the "not a backslash" character in the next match, so it
                    // should not be consumed by the first match.
                    // The "prepend a space and finally remove it" steps makes sure there is a "not a backslash" at the
                    // start of the string, so this also works if the selection begins with a bracket. We cannot solve
                    // this by anchoring with ^, because in the case that the selection starts with two brackets, this
                    // would mean a zero-width match at the start. Since zero-width matches advance the string position,
                    // the first bracket could then not act as the "not a backslash" for the second.
                    chunk.selection = (" " + chunk.selection).replace(/([^\\](?:\\\\)*)(?=[[\]])/g, "$1\\").substr(1);
                    
                    var linkDef = " [999]: " + properlyEncoded(link);

                    var num = that.addLinkDef(chunk, linkDef);
                    chunk.startTag = isImage ? "![" : "[";
                    chunk.endTag = "][" + num + "]";

                    if (!chunk.selection) {
                        if (isImage) {
                            chunk.selection = that.getString("imagedescription");
                        }
                        else {
                            chunk.selection = that.getString("linkdescription");
                        }
                    }
                }
                postProcessing();
            };

            background = ui.createBackground();

            if (isImage) {
                if (!this.hooks.insertImageDialog(linkEnteredCallback))
                    ui.prompt(this.getString("imagedialog"), imageDefaultText, linkEnteredCallback);
            }
            else {
                ui.prompt(this.getString("linkdialog"), linkDefaultText, linkEnteredCallback);
            }
            return true;
        }
    };

    // When making a list, hitting shift-enter will put your cursor on the next line
    // at the current indent level.
    commandProto.doAutoindent = function (chunk, postProcessing) {

        var commandMgr = this,
            fakeSelection = false;

        chunk.before = chunk.before.replace(/(\n|^)[ ]{0,3}([*+-]|\d+[.])[ \t]*\n$/, "\n\n");
        chunk.before = chunk.before.replace(/(\n|^)[ ]{0,3}>[ \t]*\n$/, "\n\n");
        chunk.before = chunk.before.replace(/(\n|^)[ \t]+\n$/, "\n\n");
        
        // There''s no selection, end the cursor wasn''t at the end of the line:
        // The user wants to split the current list item / code line / blockquote line
        // (for the latter it doesn''t really matter) in two. Temporarily select the
        // (rest of the) line to achieve this.
        if (!chunk.selection && !/^[ \t]*(?:\n|$)/.test(chunk.after)) {
            chunk.after = chunk.after.replace(/^[^\n]*/, function (wholeMatch) {
                chunk.selection = wholeMatch;
                return "";
            });
            fakeSelection = true;
        }

        if (/(\n|^)[ ]{0,3}([*+-]|\d+[.])[ \t]+.*\n$/.test(chunk.before)) {
            if (commandMgr.doList) {
                commandMgr.doList(chunk);
            }
        }
        if (/(\n|^)[ ]{0,3}>[ \t]+.*\n$/.test(chunk.before)) {
            if (commandMgr.doBlockquote) {
                commandMgr.doBlockquote(chunk);
            }
        }
        if (/(\n|^)(\t|[ ]{4,}).*\n$/.test(chunk.before)) {
            if (commandMgr.doCode) {
                commandMgr.doCode(chunk);
            }
        }
        
        if (fakeSelection) {
            chunk.after = chunk.selection + chunk.after;
            chunk.selection = "";
        }
    };

    commandProto.doBlockquote = function (chunk, postProcessing) {

        chunk.selection = chunk.selection.replace(/^(\n*)([^\r]+?)(\n*)$/,
            function (totalMatch, newlinesBefore, text, newlinesAfter) {
                chunk.before += newlinesBefore;
                chunk.after = newlinesAfter + chunk.after;
                return text;
            });

        chunk.before = chunk.before.replace(/(>[ \t]*)$/,
            function (totalMatch, blankLine) {
                chunk.selection = blankLine + chunk.selection;
                return "";
            });

        chunk.selection = chunk.selection.replace(/^(\s|>)+$/, "");
        chunk.selection = chunk.selection || this.getString("quoteexample");

        // The original code uses a regular expression to find out how much of the
        // text *directly before* the selection already was a blockquote:

        /*
        if (chunk.before) {
        chunk.before = chunk.before.replace(/\n?$/, "\n");
        }
        chunk.before = chunk.before.replace(/(((\n|^)(\n[ \t]*)*>(.+\n)*.*)+(\n[ \t]*)*$)/,
        function (totalMatch) {
        chunk.startTag = totalMatch;
        return "";
        });
        */

        // This comes down to:
        // Go backwards as many lines a possible, such that each line
        //  a) starts with ">", or
        //  b) is almost empty, except for whitespace, or
        //  c) is preceeded by an unbroken chain of non-empty lines
        //     leading up to a line that starts with ">" and at least one more character
        // and in addition
        //  d) at least one line fulfills a)
        //
        // Since this is essentially a backwards-moving regex, it''s susceptible to
        // catstrophic backtracking and can cause the browser to hang;
        // see e.g. http://meta.stackoverflow.com/questions/9807.
        //
        // Hence we replaced this by a simple state machine that just goes through the
        // lines and checks for a), b), and c).

        var match = "",
            leftOver = "",
            line;
        if (chunk.before) {
            var lines = chunk.before.replace(/\n$/, "").split("\n");
            var inChain = false;
            for (var i = 0; i < lines.length; i++) {
                var good = false;
                line = lines[i];
                inChain = inChain && line.length > 0; // c) any non-empty line continues the chain
                if (/^>/.test(line)) {                // a)
                    good = true;
                    if (!inChain && line.length > 1)  // c) any line that starts with ">" and has at least one more character starts the chain
                        inChain = true;
                } else if (/^[ \t]*$/.test(line)) {   // b)
                    good = true;
                } else {
                    good = inChain;                   // c) the line is not empty and does not start with ">", so it matches if and only if we''re in the chain
                }
                if (good) {
                    match += line + "\n";
                } else {
                    leftOver += match + line;
                    match = "\n";
                }
            }
            if (!/(^|\n)>/.test(match)) {             // d)
                leftOver += match;
                match = "";
            }
        }

        chunk.startTag = match;
        chunk.before = leftOver;

        // end of change

        if (chunk.after) {
            chunk.after = chunk.after.replace(/^\n?/, "\n");
        }

        chunk.after = chunk.after.replace(/^(((\n|^)(\n[ \t]*)*>(.+\n)*.*)+(\n[ \t]*)*)/,
            function (totalMatch) {
                chunk.endTag = totalMatch;
                return "";
            }
        );

        var replaceBlanksInTags = function (useBracket) {

            var replacement = useBracket ? "> " : "";

            if (chunk.startTag) {
                chunk.startTag = chunk.startTag.replace(/\n((>|\s)*)\n$/,
                    function (totalMatch, markdown) {
                        return "\n" + markdown.replace(/^[ ]{0,3}>?[ \t]*$/gm, replacement) + "\n";
                    });
            }
            if (chunk.endTag) {
                chunk.endTag = chunk.endTag.replace(/^\n((>|\s)*)\n/,
                    function (totalMatch, markdown) {
                        return "\n" + markdown.replace(/^[ ]{0,3}>?[ \t]*$/gm, replacement) + "\n";
                    });
            }
        };

        if (/^(?![ ]{0,3}>)/m.test(chunk.selection)) {
            this.wrap(chunk, SETTINGS.lineLength - 2);
            chunk.selection = chunk.selection.replace(/^/gm, "> ");
            replaceBlanksInTags(true);
            chunk.skipLines();
        } else {
            chunk.selection = chunk.selection.replace(/^[ ]{0,3}> ?/gm, "");
            this.unwrap(chunk);
            replaceBlanksInTags(false);

            if (!/^(\n|^)[ ]{0,3}>/.test(chunk.selection) && chunk.startTag) {
                chunk.startTag = chunk.startTag.replace(/\n{0,2}$/, "\n\n");
            }

            if (!/(\n|^)[ ]{0,3}>.*$/.test(chunk.selection) && chunk.endTag) {
                chunk.endTag = chunk.endTag.replace(/^\n{0,2}/, "\n\n");
            }
        }

        chunk.selection = this.hooks.postBlockquoteCreation(chunk.selection);

        if (!/\n/.test(chunk.selection)) {
            chunk.selection = chunk.selection.replace(/^(> *)/,
            function (wholeMatch, blanks) {
                chunk.startTag += blanks;
                return "";
            });
        }
    };

    commandProto.doCode = function (chunk, postProcessing) {

        var hasTextBefore = /\S[ ]*$/.test(chunk.before);
        var hasTextAfter = /^[ ]*\S/.test(chunk.after);

        // Use ''four space'' markdown if the selection is on its own
        // line or is multiline.
        if ((!hasTextAfter && !hasTextBefore) || /\n/.test(chunk.selection)) {

            chunk.before = chunk.before.replace(/[ ]{4}$/,
                function (totalMatch) {
                    chunk.selection = totalMatch + chunk.selection;
                    return "";
                });

            var nLinesBack = 1;
            var nLinesForward = 1;

            if (/(\n|^)(\t|[ ]{4,}).*\n$/.test(chunk.before)) {
                nLinesBack = 0;
            }
            if (/^\n(\t|[ ]{4,})/.test(chunk.after)) {
                nLinesForward = 0;
            }

            chunk.skipLines(nLinesBack, nLinesForward);

            if (!chunk.selection) {
                chunk.startTag = "    ";
                chunk.selection = this.getString("codeexample");
            }
            else {
                if (/^[ ]{0,3}\S/m.test(chunk.selection)) {
                    if (/\n/.test(chunk.selection))
                        chunk.selection = chunk.selection.replace(/^/gm, "    ");
                    else // if it''s not multiline, do not select the four added spaces; this is more consistent with the doList behavior
                        chunk.before += "    ";
                }
                else {
                    chunk.selection = chunk.selection.replace(/^[ ]{4}/gm, "");
                }
            }
        }
        else {
            // Use backticks (`) to delimit the code block.

            chunk.trimWhitespace();
            chunk.findTags(/`/, /`/);

            if (!chunk.startTag && !chunk.endTag) {
                chunk.startTag = chunk.endTag = "`";
                if (!chunk.selection) {
                    chunk.selection = this.getString("codeexample");
                }
            }
            else if (chunk.endTag && !chunk.startTag) {
                chunk.before += chunk.endTag;
                chunk.endTag = "";
            }
            else {
                chunk.startTag = chunk.endTag = "";
            }
        }
    };

    commandProto.doList = function (chunk, postProcessing, isNumberedList) {

        // These are identical except at the very beginning and end.
        // Should probably use the regex extension function to make this clearer.
        var previousItemsRegex = /(\n|^)(([ ]{0,3}([*+-]|\d+[.])[ \t]+.*)(\n.+|\n{2,}([*+-].*|\d+[.])[ \t]+.*|\n{2,}[ \t]+\S.*)*)\n*$/;
        var nextItemsRegex = /^\n*(([ ]{0,3}([*+-]|\d+[.])[ \t]+.*)(\n.+|\n{2,}([*+-].*|\d+[.])[ \t]+.*|\n{2,}[ \t]+\S.*)*)\n*/;

        // The default bullet is a dash but others are possible.
        // This has nothing to do with the particular HTML bullet,
        // it''s just a markdown bullet.
        var bullet = "-";

        // The number in a numbered list.
        var num = 1;

        // Get the item prefix - e.g. " 1. " for a numbered list, " - " for a bulleted list.
        var getItemPrefix = function () {
            var prefix;
            if (isNumberedList) {
                prefix = " " + num + ". ";
                num++;
            }
            else {
                prefix = " " + bullet + " ";
            }
            return prefix;
        };

        // Fixes the prefixes of the other list items.
        var getPrefixedItem = function (itemText) {

            // The numbering flag is unset when called by autoindent.
            if (isNumberedList === undefined) {
                isNumberedList = /^\s*\d/.test(itemText);
            }

            // Renumber/bullet the list element.
            itemText = itemText.replace(/^[ ]{0,3}([*+-]|\d+[.])\s/gm,
                function (_) {
                    return getItemPrefix();
                });

            return itemText;
        };

        chunk.findTags(/(\n|^)*[ ]{0,3}([*+-]|\d+[.])\s+/, null);

        if (chunk.before && !/\n$/.test(chunk.before) && !/^\n/.test(chunk.startTag)) {
            chunk.before += chunk.startTag;
            chunk.startTag = "";
        }

        if (chunk.startTag) {

            var hasDigits = /\d+[.]/.test(chunk.startTag);
            chunk.startTag = "";
            chunk.selection = chunk.selection.replace(/\n[ ]{4}/g, "\n");
            this.unwrap(chunk);
            chunk.skipLines();

            if (hasDigits) {
                // Have to renumber the bullet points if this is a numbered list.
                chunk.after = chunk.after.replace(nextItemsRegex, getPrefixedItem);
            }
            if (isNumberedList == hasDigits) {
                return;
            }
        }

        var nLinesUp = 1;

        chunk.before = chunk.before.replace(previousItemsRegex,
            function (itemText) {
                if (/^\s*([*+-])/.test(itemText)) {
                    bullet = re.$1;
                }
                nLinesUp = /[^\n]\n\n[^\n]/.test(itemText) ? 1 : 0;
                return getPrefixedItem(itemText);
            });

        if (!chunk.selection) {
            chunk.selection = this.getString("litem");
        }

        var prefix = getItemPrefix();

        var nLinesDown = 1;

        chunk.after = chunk.after.replace(nextItemsRegex,
            function (itemText) {
                nLinesDown = /[^\n]\n\n[^\n]/.test(itemText) ? 1 : 0;
                return getPrefixedItem(itemText);
            });

        chunk.trimWhitespace(true);
        chunk.skipLines(nLinesUp, nLinesDown, true);
        chunk.startTag = prefix;
        var spaces = prefix.replace(/./g, " ");
        this.wrap(chunk, SETTINGS.lineLength - spaces.length);
        chunk.selection = chunk.selection.replace(/\n/g, "\n" + spaces);

    };

    commandProto.doHeading = function (chunk, postProcessing) {

        // Remove leading/trailing whitespace and reduce internal spaces to single spaces.
        chunk.selection = chunk.selection.replace(/\s+/g, " ");
        chunk.selection = chunk.selection.replace(/(^\s+|\s+$)/g, "");

        // If we clicked the button with no selected text, we just
        // make a level 2 hash header around some default text.
        if (!chunk.selection) {
            chunk.startTag = "## ";
            chunk.selection = this.getString("headingexample");
            chunk.endTag = " ##";
            return;
        }

        var headerLevel = 0;     // The existing header level of the selected text.

        // Remove any existing hash heading markdown and save the header level.
        chunk.findTags(/#+[ ]*/, /[ ]*#+/);
        if (/#+/.test(chunk.startTag)) {
            headerLevel = re.lastMatch.length;
        }
        chunk.startTag = chunk.endTag = "";

        // Try to get the current header level by looking for - and = in the line
        // below the selection.
        chunk.findTags(null, /\s?(-+|=+)/);
        if (/=+/.test(chunk.endTag)) {
            headerLevel = 1;
        }
        if (/-+/.test(chunk.endTag)) {
            headerLevel = 2;
        }

        // Skip to the next line so we can create the header markdown.
        chunk.startTag = chunk.endTag = "";
        chunk.skipLines(1, 1);

        // We make a level 2 header if there is no current header.
        // If there is a header level, we substract one from the header level.
        // If it''s already a level 1 header, it''s removed.
        var headerLevelToCreate = headerLevel == 0 ? 2 : headerLevel - 1;

        if (headerLevelToCreate > 0) {

            // The button only creates level 1 and 2 underline headers.
            // Why not have it iterate over hash header levels?  Wouldn''t that be easier and cleaner?
            var headerChar = headerLevelToCreate >= 2 ? "-" : "=";
            var len = chunk.selection.length;
            if (len > SETTINGS.lineLength) {
                len = SETTINGS.lineLength;
            }
            chunk.endTag = "\n";
            while (len--) {
                chunk.endTag += headerChar;
            }
        }
    };

    commandProto.doHorizontalRule = function (chunk, postProcessing) {
        chunk.startTag = "----------\n";
        chunk.selection = "";
        chunk.skipLines(2, 1, true);
    }


})();'
]

{ #category : #uploads }
OHFileRequestHandler >> MarkdownSanitizerJs [
	^ '(function () {
    var output, Converter;
    if (typeof exports === "object" && typeof require === "function") { // we''re in a CommonJS (e.g. Node.js) module
        output = exports;
        Converter = require("./Markdown.Converter").Converter;
    } else {
        output = window.Markdown;
        Converter = output.Converter;
    }
        
    output.getSanitizingConverter = function () {
        var converter = new Converter();
        converter.hooks.chain("postConversion", sanitizeHtml);
        converter.hooks.chain("postConversion", balanceTags);
        return converter;
    }

    function sanitizeHtml(html) {
        return html.replace(/<[^>]*>?/gi, sanitizeTag);
    }

    // (tags that can be opened/closed) | (tags that stand alone)
    var basic_tag_whitelist = /^(<\/?(b|blockquote|code|del|dd|dl|dt|em|h1|h2|h3|i|kbd|li|ol|p|pre|s|sup|sub|strong|strike|ul)>|<(br|hr)\s?\/?>)$/i;
    // <a href="url..." optional title>|</a>
    var a_white = /^(<a\shref="((https?|ftp):\/\/|\/)[-A-Za-z0-9+&@#\/%?=~_|!:,.;\(\)]+"(\stitle="[^"<>]+")?\s?>|<\/a>)$/i;

    // <img src="url..." optional width  optional height  optional alt  optional title
    var img_white = /^(<img\ssrc="(https?:\/\/|\/)[-A-Za-z0-9+&@#\/%?=~_|!:,.;\(\)]+"(\swidth="\d{1,3}")?(\sheight="\d{1,3}")?(\salt="[^"<>]*")?(\stitle="[^"<>]*")?\s?\/?>)$/i;

    function sanitizeTag(tag) {
        if (tag.match(basic_tag_whitelist) || tag.match(a_white) || tag.match(img_white))
            return tag;
        else
            return "";
    }

    /// <summary>
    /// attempt to balance HTML tags in the html string
    /// by removing any unmatched opening or closing tags
    /// IMPORTANT: we *assume* HTML has *already* been 
    /// sanitized and is safe/sane before balancing!
    /// 
    /// adapted from CODESNIPPET: A8591DBA-D1D3-11DE-947C-BA5556D89593
    /// </summary>
    function balanceTags(html) {

        if (html == "")
            return "";

        var re = /<\/?\w+[^>]*(\s|$|>)/g;
        // convert everything to lower case; this makes
        // our case insensitive comparisons easier
        var tags = html.toLowerCase().match(re);

        // no HTML tags present? nothing to do; exit now
        var tagcount = (tags || []).length;
        if (tagcount == 0)
            return html;

        var tagname, tag;
        var ignoredtags = "<p><img><br><li><hr>";
        var match;
        var tagpaired = [];
        var tagremove = [];
        var needsRemoval = false;

        // loop through matched tags in forward order
        for (var ctag = 0; ctag < tagcount; ctag++) {
            tagname = tags[ctag].replace(/<\/?(\w+).*/, "$1");
            // skip any already paired tags
            // and skip tags in our ignore list; assume they''re self-closed
            if (tagpaired[ctag] || ignoredtags.search("<" + tagname + ">") > -1)
                continue;

            tag = tags[ctag];
            match = -1;

            if (!/^<\//.test(tag)) {
                // this is an opening tag
                // search forwards (next tags), look for closing tags
                for (var ntag = ctag + 1; ntag < tagcount; ntag++) {
                    if (!tagpaired[ntag] && tags[ntag] == "</" + tagname + ">") {
                        match = ntag;
                        break;
                    }
                }
            }

            if (match == -1)
                needsRemoval = tagremove[ctag] = true; // mark for removal
            else
                tagpaired[match] = true; // mark paired
        }

        if (!needsRemoval)
            return html;

        // delete all orphaned tags from the string

        var ctag = 0;
        html = html.replace(re, function (match) {
            var res = tagremove[ctag] ? "" : match;
            ctag++;
            return res;
        });
        return html;
    }
})();
'
]

{ #category : #private }
OHFileRequestHandler >> cssResponseFor: aContentSelector [

	^self respondWith: (self perform: aContentSelector) usingMIMEType: 'text/css'
	
]

{ #category : #uploads }
OHFileRequestHandler >> cssbootstrapminCssContent [
	^ '/*!
 * Bootstrap v2.2.2
 *
 * Copyright 2012 Twitter, Inc
 * Licensed under the Apache License v2.0
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Designed and built with all the love in the world @twitter by @mdo and @fat.
 */article,aside,details,figcaption,figure,footer,header,hgroup,nav,section{display:block}audio,canvas,video{display:inline-block;*display:inline;*zoom:1}audio:not([controls]){display:none}html{font-size:100%;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%}a:focus{outline:thin dotted #333;outline:5px auto -webkit-focus-ring-color;outline-offset:-2px}a:hover,a:active{outline:0}sub,sup{position:relative;font-size:75%;line-height:0;vertical-align:baseline}sup{top:-0.5em}sub{bottom:-0.25em}img{width:auto\9;height:auto;max-width:100%;vertical-align:middle;border:0;-ms-interpolation-mode:bicubic}#map_canvas img,.google-maps img{max-width:none}button,input,select,textarea{margin:0;font-size:100%;vertical-align:middle}button,input{*overflow:visible;line-height:normal}button::-moz-focus-inner,input::-moz-focus-inner{padding:0;border:0}button,html input[type="button"],input[type="reset"],input[type="submit"]{cursor:pointer;-webkit-appearance:button}label,select,button,input[type="button"],input[type="reset"],input[type="submit"],input[type="radio"],input[type="checkbox"]{cursor:pointer}input[type="search"]{-webkit-box-sizing:content-box;-moz-box-sizing:content-box;box-sizing:content-box;-webkit-appearance:textfield}input[type="search"]::-webkit-search-decoration,input[type="search"]::-webkit-search-cancel-button{-webkit-appearance:none}textarea{overflow:auto;vertical-align:top}@media print{*{color:#000!important;text-shadow:none!important;background:transparent!important;box-shadow:none!important}a,a:visited{text-decoration:underline}a[href]:after{content:" (" attr(href) ")"}abbr[title]:after{content:" (" attr(title) ")"}.ir a:after,a[href^="javascript:"]:after,a[href^="#"]:after{content:""}pre,blockquote{border:1px solid #999;page-break-inside:avoid}thead{display:table-header-group}tr,img{page-break-inside:avoid}img{max-width:100%!important}@page{margin:.5cm}p,h2,h3{orphans:3;widows:3}h2,h3{page-break-after:avoid}}.clearfix{*zoom:1}.clearfix:before,.clearfix:after{display:table;line-height:0;content:""}.clearfix:after{clear:both}.hide-text{font:0/0 a;color:transparent;text-shadow:none;background-color:transparent;border:0}.input-block-level{display:block;width:100%;min-height:30px;-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box}body{margin:0;font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;font-size:14px;line-height:20px;color:#333;background-color:#fff}a{color:#08c;text-decoration:none}a:hover{color:#005580;text-decoration:underline}.img-rounded{-webkit-border-radius:6px;-moz-border-radius:6px;border-radius:6px}.img-polaroid{padding:4px;background-color:#fff;border:1px solid #ccc;border:1px solid rgba(0,0,0,0.2);-webkit-box-shadow:0 1px 3px rgba(0,0,0,0.1);-moz-box-shadow:0 1px 3px rgba(0,0,0,0.1);box-shadow:0 1px 3px rgba(0,0,0,0.1)}.img-circle{-webkit-border-radius:500px;-moz-border-radius:500px;border-radius:500px}.row{margin-left:-20px;*zoom:1}.row:before,.row:after{display:table;line-height:0;content:""}.row:after{clear:both}[class*="span"]{float:left;min-height:1px;margin-left:20px}.container,.navbar-static-top .container,.navbar-fixed-top .container,.navbar-fixed-bottom .container{width:940px}.span12{width:940px}.span11{width:860px}.span10{width:780px}.span9{width:700px}.span8{width:620px}.span7{width:540px}.span6{width:460px}.span5{width:380px}.span4{width:300px}.span3{width:220px}.span2{width:140px}.span1{width:60px}.offset12{margin-left:980px}.offset11{margin-left:900px}.offset10{margin-left:820px}.offset9{margin-left:740px}.offset8{margin-left:660px}.offset7{margin-left:580px}.offset6{margin-left:500px}.offset5{margin-left:420px}.offset4{margin-left:340px}.offset3{margin-left:260px}.offset2{margin-left:180px}.offset1{margin-left:100px}.row-fluid{width:100%;*zoom:1}.row-fluid:before,.row-fluid:after{display:table;line-height:0;content:""}.row-fluid:after{clear:both}.row-fluid [class*="span"]{display:block;float:left;width:100%;min-height:30px;margin-left:2.127659574468085%;*margin-left:2.074468085106383%;-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box}.row-fluid [class*="span"]:first-child{margin-left:0}.row-fluid .controls-row [class*="span"]+[class*="span"]{margin-left:2.127659574468085%}.row-fluid .span12{width:100%;*width:99.94680851063829%}.row-fluid .span11{width:91.48936170212765%;*width:91.43617021276594%}.row-fluid .span10{width:82.97872340425532%;*width:82.92553191489361%}.row-fluid .span9{width:74.46808510638297%;*width:74.41489361702126%}.row-fluid .span8{width:65.95744680851064%;*width:65.90425531914893%}.row-fluid .span7{width:57.44680851063829%;*width:57.39361702127659%}.row-fluid .span6{width:48.93617021276595%;*width:48.88297872340425%}.row-fluid .span5{width:40.42553191489362%;*width:40.37234042553192%}.row-fluid .span4{width:31.914893617021278%;*width:31.861702127659576%}.row-fluid .span3{width:23.404255319148934%;*width:23.351063829787233%}.row-fluid .span2{width:14.893617021276595%;*width:14.840425531914894%}.row-fluid .span1{width:6.382978723404255%;*width:6.329787234042553%}.row-fluid .offset12{margin-left:104.25531914893617%;*margin-left:104.14893617021275%}.row-fluid .offset12:first-child{margin-left:102.12765957446808%;*margin-left:102.02127659574467%}.row-fluid .offset11{margin-left:95.74468085106382%;*margin-left:95.6382978723404%}.row-fluid .offset11:first-child{margin-left:93.61702127659574%;*margin-left:93.51063829787232%}.row-fluid .offset10{margin-left:87.23404255319149%;*margin-left:87.12765957446807%}.row-fluid .offset10:first-child{margin-left:85.1063829787234%;*margin-left:84.99999999999999%}.row-fluid .offset9{margin-left:78.72340425531914%;*margin-left:78.61702127659572%}.row-fluid .offset9:first-child{margin-left:76.59574468085106%;*margin-left:76.48936170212764%}.row-fluid .offset8{margin-left:70.2127659574468%;*margin-left:70.10638297872339%}.row-fluid .offset8:first-child{margin-left:68.08510638297872%;*margin-left:67.9787234042553%}.row-fluid .offset7{margin-left:61.70212765957446%;*margin-left:61.59574468085106%}.row-fluid .offset7:first-child{margin-left:59.574468085106375%;*margin-left:59.46808510638297%}.row-fluid .offset6{margin-left:53.191489361702125%;*margin-left:53.085106382978715%}.row-fluid .offset6:first-child{margin-left:51.063829787234035%;*margin-left:50.95744680851063%}.row-fluid .offset5{margin-left:44.68085106382979%;*margin-left:44.57446808510638%}.row-fluid .offset5:first-child{margin-left:42.5531914893617%;*margin-left:42.4468085106383%}.row-fluid .offset4{margin-left:36.170212765957444%;*margin-left:36.06382978723405%}.row-fluid .offset4:first-child{margin-left:34.04255319148936%;*margin-left:33.93617021276596%}.row-fluid .offset3{margin-left:27.659574468085104%;*margin-left:27.5531914893617%}.row-fluid .offset3:first-child{margin-left:25.53191489361702%;*margin-left:25.425531914893618%}.row-fluid .offset2{margin-left:19.148936170212764%;*margin-left:19.04255319148936%}.row-fluid .offset2:first-child{margin-left:17.02127659574468%;*margin-left:16.914893617021278%}.row-fluid .offset1{margin-left:10.638297872340425%;*margin-left:10.53191489361702%}.row-fluid .offset1:first-child{margin-left:8.51063829787234%;*margin-left:8.404255319148938%}[class*="span"].hide,.row-fluid [class*="span"].hide{display:none}[class*="span"].pull-right,.row-fluid [class*="span"].pull-right{float:right}.container{margin-right:auto;margin-left:auto;*zoom:1}.container:before,.container:after{display:table;line-height:0;content:""}.container:after{clear:both}.container-fluid{padding-right:20px;padding-left:20px;*zoom:1}.container-fluid:before,.container-fluid:after{display:table;line-height:0;content:""}.container-fluid:after{clear:both}p{margin:0 0 10px}.lead{margin-bottom:20px;font-size:21px;font-weight:200;line-height:30px}small{font-size:85%}strong{font-weight:bold}em{font-style:italic}cite{font-style:normal}.muted{color:#999}a.muted:hover{color:#808080}.text-warning{color:#c09853}a.text-warning:hover{color:#a47e3c}.text-error{color:#b94a48}a.text-error:hover{color:#953b39}.text-info{color:#3a87ad}a.text-info:hover{color:#2d6987}.text-success{color:#468847}a.text-success:hover{color:#356635}h1,h2,h3,h4,h5,h6{margin:10px 0;font-family:inherit;font-weight:bold;line-height:20px;color:inherit;text-rendering:optimizelegibility}h1 small,h2 small,h3 small,h4 small,h5 small,h6 small{font-weight:normal;line-height:1;color:#999}h1,h2,h3{line-height:40px}h1{font-size:38.5px}h2{font-size:31.5px}h3{font-size:24.5px}h4{font-size:17.5px}h5{font-size:14px}h6{font-size:11.9px}h1 small{font-size:24.5px}h2 small{font-size:17.5px}h3 small{font-size:14px}h4 small{font-size:14px}.page-header{padding-bottom:9px;margin:20px 0 30px;border-bottom:1px solid #eee}ul,ol{padding:0;margin:0 0 10px 25px}ul ul,ul ol,ol ol,ol ul{margin-bottom:0}li{line-height:20px}ul.unstyled,ol.unstyled{margin-left:0;list-style:none}ul.inline,ol.inline{margin-left:0;list-style:none}ul.inline>li,ol.inline>li{display:inline-block;padding-right:5px;padding-left:5px}dl{margin-bottom:20px}dt,dd{line-height:20px}dt{font-weight:bold}dd{margin-left:10px}.dl-horizontal{*zoom:1}.dl-horizontal:before,.dl-horizontal:after{display:table;line-height:0;content:""}.dl-horizontal:after{clear:both}.dl-horizontal dt{float:left;width:160px;overflow:hidden;clear:left;text-align:right;text-overflow:ellipsis;white-space:nowrap}.dl-horizontal dd{margin-left:180px}hr{margin:20px 0;border:0;border-top:1px solid #eee;border-bottom:1px solid #fff}abbr[title],abbr[data-original-title]{cursor:help;border-bottom:1px dotted #999}abbr.initialism{font-size:90%;text-transform:uppercase}blockquote{padding:0 0 0 15px;margin:0 0 20px;border-left:5px solid #eee}blockquote p{margin-bottom:0;font-size:16px;font-weight:300;line-height:25px}blockquote small{display:block;line-height:20px;color:#999}blockquote small:before{content:''\2014 \00A0''}blockquote.pull-right{float:right;padding-right:15px;padding-left:0;border-right:5px solid #eee;border-left:0}blockquote.pull-right p,blockquote.pull-right small{text-align:right}blockquote.pull-right small:before{content:''''}blockquote.pull-right small:after{content:''\00A0 \2014''}q:before,q:after,blockquote:before,blockquote:after{content:""}address{display:block;margin-bottom:20px;font-style:normal;line-height:20px}code,pre{padding:0 3px 2px;font-family:Monaco,Menlo,Consolas,"Courier New",monospace;font-size:12px;color:#333;-webkit-border-radius:3px;-moz-border-radius:3px;border-radius:3px}code{padding:2px 4px;color:#d14;white-space:nowrap;background-color:#f7f7f9;border:1px solid #e1e1e8}pre{display:block;padding:9.5px;margin:0 0 10px;font-size:13px;line-height:20px;word-break:break-all;word-wrap:break-word;white-space:pre;white-space:pre-wrap;background-color:#f5f5f5;border:1px solid #ccc;border:1px solid rgba(0,0,0,0.15);-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px}pre.prettyprint{margin-bottom:20px}pre code{padding:0;color:inherit;white-space:pre;white-space:pre-wrap;background-color:transparent;border:0}.pre-scrollable{max-height:340px;overflow-y:scroll}form{margin:0 0 20px}fieldset{padding:0;margin:0;border:0}legend{display:block;width:100%;padding:0;margin-bottom:20px;font-size:21px;line-height:40px;color:#333;border:0;border-bottom:1px solid #e5e5e5}legend small{font-size:15px;color:#999}label,input,button,select,textarea{font-size:14px;font-weight:normal;line-height:20px}input,button,select,textarea{font-family:"Helvetica Neue",Helvetica,Arial,sans-serif}label{display:block;margin-bottom:5px}select,textarea,input[type="text"],input[type="password"],input[type="datetime"],input[type="datetime-local"],input[type="date"],input[type="month"],input[type="time"],input[type="week"],input[type="number"],input[type="email"],input[type="url"],input[type="search"],input[type="tel"],input[type="color"],.uneditable-input{display:inline-block;height:20px;padding:4px 6px;margin-bottom:10px;font-size:14px;line-height:20px;color:#555;vertical-align:middle;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px}input,textarea,.uneditable-input{width:206px}textarea{height:auto}textarea,input[type="text"],input[type="password"],input[type="datetime"],input[type="datetime-local"],input[type="date"],input[type="month"],input[type="time"],input[type="week"],input[type="number"],input[type="email"],input[type="url"],input[type="search"],input[type="tel"],input[type="color"],.uneditable-input{background-color:#fff;border:1px solid #ccc;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);-webkit-transition:border linear .2s,box-shadow linear .2s;-moz-transition:border linear .2s,box-shadow linear .2s;-o-transition:border linear .2s,box-shadow linear .2s;transition:border linear .2s,box-shadow linear .2s}textarea:focus,input[type="text"]:focus,input[type="password"]:focus,input[type="datetime"]:focus,input[type="datetime-local"]:focus,input[type="date"]:focus,input[type="month"]:focus,input[type="time"]:focus,input[type="week"]:focus,input[type="number"]:focus,input[type="email"]:focus,input[type="url"]:focus,input[type="search"]:focus,input[type="tel"]:focus,input[type="color"]:focus,.uneditable-input:focus{border-color:rgba(82,168,236,0.8);outline:0;outline:thin dotted \9;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 8px rgba(82,168,236,0.6);-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 8px rgba(82,168,236,0.6);box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 8px rgba(82,168,236,0.6)}input[type="radio"],input[type="checkbox"]{margin:4px 0 0;margin-top:1px \9;*margin-top:0;line-height:normal}input[type="file"],input[type="image"],input[type="submit"],input[type="reset"],input[type="button"],input[type="radio"],input[type="checkbox"]{width:auto}select,input[type="file"]{height:30px;*margin-top:4px;line-height:30px}select{width:220px;background-color:#fff;border:1px solid #ccc}select[multiple],select[size]{height:auto}select:focus,input[type="file"]:focus,input[type="radio"]:focus,input[type="checkbox"]:focus{outline:thin dotted #333;outline:5px auto -webkit-focus-ring-color;outline-offset:-2px}.uneditable-input,.uneditable-textarea{color:#999;cursor:not-allowed;background-color:#fcfcfc;border-color:#ccc;-webkit-box-shadow:inset 0 1px 2px rgba(0,0,0,0.025);-moz-box-shadow:inset 0 1px 2px rgba(0,0,0,0.025);box-shadow:inset 0 1px 2px rgba(0,0,0,0.025)}.uneditable-input{overflow:hidden;white-space:nowrap}.uneditable-textarea{width:auto;height:auto}input:-moz-placeholder,textarea:-moz-placeholder{color:#999}input:-ms-input-placeholder,textarea:-ms-input-placeholder{color:#999}input::-webkit-input-placeholder,textarea::-webkit-input-placeholder{color:#999}.radio,.checkbox{min-height:20px;padding-left:20px}.radio input[type="radio"],.checkbox input[type="checkbox"]{float:left;margin-left:-20px}.controls>.radio:first-child,.controls>.checkbox:first-child{padding-top:5px}.radio.inline,.checkbox.inline{display:inline-block;padding-top:5px;margin-bottom:0;vertical-align:middle}.radio.inline+.radio.inline,.checkbox.inline+.checkbox.inline{margin-left:10px}.input-mini{width:60px}.input-small{width:90px}.input-medium{width:150px}.input-large{width:210px}.input-xlarge{width:270px}.input-xxlarge{width:530px}input[class*="span"],select[class*="span"],textarea[class*="span"],.uneditable-input[class*="span"],.row-fluid input[class*="span"],.row-fluid select[class*="span"],.row-fluid textarea[class*="span"],.row-fluid .uneditable-input[class*="span"]{float:none;margin-left:0}.input-append input[class*="span"],.input-append .uneditable-input[class*="span"],.input-prepend input[class*="span"],.input-prepend .uneditable-input[class*="span"],.row-fluid input[class*="span"],.row-fluid select[class*="span"],.row-fluid textarea[class*="span"],.row-fluid .uneditable-input[class*="span"],.row-fluid .input-prepend [class*="span"],.row-fluid .input-append [class*="span"]{display:inline-block}input,textarea,.uneditable-input{margin-left:0}.controls-row [class*="span"]+[class*="span"]{margin-left:20px}input.span12,textarea.span12,.uneditable-input.span12{width:926px}input.span11,textarea.span11,.uneditable-input.span11{width:846px}input.span10,textarea.span10,.uneditable-input.span10{width:766px}input.span9,textarea.span9,.uneditable-input.span9{width:686px}input.span8,textarea.span8,.uneditable-input.span8{width:606px}input.span7,textarea.span7,.uneditable-input.span7{width:526px}input.span6,textarea.span6,.uneditable-input.span6{width:446px}input.span5,textarea.span5,.uneditable-input.span5{width:366px}input.span4,textarea.span4,.uneditable-input.span4{width:286px}input.span3,textarea.span3,.uneditable-input.span3{width:206px}input.span2,textarea.span2,.uneditable-input.span2{width:126px}input.span1,textarea.span1,.uneditable-input.span1{width:46px}.controls-row{*zoom:1}.controls-row:before,.controls-row:after{display:table;line-height:0;content:""}.controls-row:after{clear:both}.controls-row [class*="span"],.row-fluid .controls-row [class*="span"]{float:left}.controls-row .checkbox[class*="span"],.controls-row .radio[class*="span"]{padding-top:5px}input[disabled],select[disabled],textarea[disabled],input[readonly],select[readonly],textarea[readonly]{cursor:not-allowed;background-color:#eee}input[type="radio"][disabled],input[type="checkbox"][disabled],input[type="radio"][readonly],input[type="checkbox"][readonly]{background-color:transparent}.control-group.warning .control-label,.control-group.warning .help-block,.control-group.warning .help-inline{color:#c09853}.control-group.warning .checkbox,.control-group.warning .radio,.control-group.warning input,.control-group.warning select,.control-group.warning textarea{color:#c09853}.control-group.warning input,.control-group.warning select,.control-group.warning textarea{border-color:#c09853;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);box-shadow:inset 0 1px 1px rgba(0,0,0,0.075)}.control-group.warning input:focus,.control-group.warning select:focus,.control-group.warning textarea:focus{border-color:#a47e3c;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #dbc59e;-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #dbc59e;box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #dbc59e}.control-group.warning .input-prepend .add-on,.control-group.warning .input-append .add-on{color:#c09853;background-color:#fcf8e3;border-color:#c09853}.control-group.error .control-label,.control-group.error .help-block,.control-group.error .help-inline{color:#b94a48}.control-group.error .checkbox,.control-group.error .radio,.control-group.error input,.control-group.error select,.control-group.error textarea{color:#b94a48}.control-group.error input,.control-group.error select,.control-group.error textarea{border-color:#b94a48;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);box-shadow:inset 0 1px 1px rgba(0,0,0,0.075)}.control-group.error input:focus,.control-group.error select:focus,.control-group.error textarea:focus{border-color:#953b39;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #d59392;-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #d59392;box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #d59392}.control-group.error .input-prepend .add-on,.control-group.error .input-append .add-on{color:#b94a48;background-color:#f2dede;border-color:#b94a48}.control-group.success .control-label,.control-group.success .help-block,.control-group.success .help-inline{color:#468847}.control-group.success .checkbox,.control-group.success .radio,.control-group.success input,.control-group.success select,.control-group.success textarea{color:#468847}.control-group.success input,.control-group.success select,.control-group.success textarea{border-color:#468847;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);box-shadow:inset 0 1px 1px rgba(0,0,0,0.075)}.control-group.success input:focus,.control-group.success select:focus,.control-group.success textarea:focus{border-color:#356635;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #7aba7b;-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #7aba7b;box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #7aba7b}.control-group.success .input-prepend .add-on,.control-group.success .input-append .add-on{color:#468847;background-color:#dff0d8;border-color:#468847}.control-group.info .control-label,.control-group.info .help-block,.control-group.info .help-inline{color:#3a87ad}.control-group.info .checkbox,.control-group.info .radio,.control-group.info input,.control-group.info select,.control-group.info textarea{color:#3a87ad}.control-group.info input,.control-group.info select,.control-group.info textarea{border-color:#3a87ad;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075);box-shadow:inset 0 1px 1px rgba(0,0,0,0.075)}.control-group.info input:focus,.control-group.info select:focus,.control-group.info textarea:focus{border-color:#2d6987;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #7ab5d3;-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #7ab5d3;box-shadow:inset 0 1px 1px rgba(0,0,0,0.075),0 0 6px #7ab5d3}.control-group.info .input-prepend .add-on,.control-group.info .input-append .add-on{color:#3a87ad;background-color:#d9edf7;border-color:#3a87ad}input:focus:invalid,textarea:focus:invalid,select:focus:invalid{color:#b94a48;border-color:#ee5f5b}input:focus:invalid:focus,textarea:focus:invalid:focus,select:focus:invalid:focus{border-color:#e9322d;-webkit-box-shadow:0 0 6px #f8b9b7;-moz-box-shadow:0 0 6px #f8b9b7;box-shadow:0 0 6px #f8b9b7}.form-actions{padding:19px 20px 20px;margin-top:20px;margin-bottom:20px;background-color:#f5f5f5;border-top:1px solid #e5e5e5;*zoom:1}.form-actions:before,.form-actions:after{display:table;line-height:0;content:""}.form-actions:after{clear:both}.help-block,.help-inline{color:#595959}.help-block{display:block;margin-bottom:10px}.help-inline{display:inline-block;*display:inline;padding-left:5px;vertical-align:middle;*zoom:1}.input-append,.input-prepend{margin-bottom:5px;font-size:0;white-space:nowrap}.input-append input,.input-prepend input,.input-append select,.input-prepend select,.input-append .uneditable-input,.input-prepend .uneditable-input,.input-append .dropdown-menu,.input-prepend .dropdown-menu{font-size:14px}.input-append input,.input-prepend input,.input-append select,.input-prepend select,.input-append .uneditable-input,.input-prepend .uneditable-input{position:relative;margin-bottom:0;*margin-left:0;vertical-align:top;-webkit-border-radius:0 4px 4px 0;-moz-border-radius:0 4px 4px 0;border-radius:0 4px 4px 0}.input-append input:focus,.input-prepend input:focus,.input-append select:focus,.input-prepend select:focus,.input-append .uneditable-input:focus,.input-prepend .uneditable-input:focus{z-index:2}.input-append .add-on,.input-prepend .add-on{display:inline-block;width:auto;height:20px;min-width:16px;padding:4px 5px;font-size:14px;font-weight:normal;line-height:20px;text-align:center;text-shadow:0 1px 0 #fff;background-color:#eee;border:1px solid #ccc}.input-append .add-on,.input-prepend .add-on,.input-append .btn,.input-prepend .btn,.input-append .btn-group>.dropdown-toggle,.input-prepend .btn-group>.dropdown-toggle{vertical-align:top;-webkit-border-radius:0;-moz-border-radius:0;border-radius:0}.input-append .active,.input-prepend .active{background-color:#a9dba9;border-color:#46a546}.input-prepend .add-on,.input-prepend .btn{margin-right:-1px}.input-prepend .add-on:first-child,.input-prepend .btn:first-child{-webkit-border-radius:4px 0 0 4px;-moz-border-radius:4px 0 0 4px;border-radius:4px 0 0 4px}.input-append input,.input-append select,.input-append .uneditable-input{-webkit-border-radius:4px 0 0 4px;-moz-border-radius:4px 0 0 4px;border-radius:4px 0 0 4px}.input-append input+.btn-group .btn:last-child,.input-append select+.btn-group .btn:last-child,.input-append .uneditable-input+.btn-group .btn:last-child{-webkit-border-radius:0 4px 4px 0;-moz-border-radius:0 4px 4px 0;border-radius:0 4px 4px 0}.input-append .add-on,.input-append .btn,.input-append .btn-group{margin-left:-1px}.input-append .add-on:last-child,.input-append .btn:last-child,.input-append .btn-group:last-child>.dropdown-toggle{-webkit-border-radius:0 4px 4px 0;-moz-border-radius:0 4px 4px 0;border-radius:0 4px 4px 0}.input-prepend.input-append input,.input-prepend.input-append select,.input-prepend.input-append .uneditable-input{-webkit-border-radius:0;-moz-border-radius:0;border-radius:0}.input-prepend.input-append input+.btn-group .btn,.input-prepend.input-append select+.btn-group .btn,.input-prepend.input-append .uneditable-input+.btn-group .btn{-webkit-border-radius:0 4px 4px 0;-moz-border-radius:0 4px 4px 0;border-radius:0 4px 4px 0}.input-prepend.input-append .add-on:first-child,.input-prepend.input-append .btn:first-child{margin-right:-1px;-webkit-border-radius:4px 0 0 4px;-moz-border-radius:4px 0 0 4px;border-radius:4px 0 0 4px}.input-prepend.input-append .add-on:last-child,.input-prepend.input-append .btn:last-child{margin-left:-1px;-webkit-border-radius:0 4px 4px 0;-moz-border-radius:0 4px 4px 0;border-radius:0 4px 4px 0}.input-prepend.input-append .btn-group:first-child{margin-left:0}input.search-query{padding-right:14px;padding-right:4px \9;padding-left:14px;padding-left:4px \9;margin-bottom:0;-webkit-border-radius:15px;-moz-border-radius:15px;border-radius:15px}.form-search .input-append .search-query,.form-search .input-prepend .search-query{-webkit-border-radius:0;-moz-border-radius:0;border-radius:0}.form-search .input-append .search-query{-webkit-border-radius:14px 0 0 14px;-moz-border-radius:14px 0 0 14px;border-radius:14px 0 0 14px}.form-search .input-append .btn{-webkit-border-radius:0 14px 14px 0;-moz-border-radius:0 14px 14px 0;border-radius:0 14px 14px 0}.form-search .input-prepend .search-query{-webkit-border-radius:0 14px 14px 0;-moz-border-radius:0 14px 14px 0;border-radius:0 14px 14px 0}.form-search .input-prepend .btn{-webkit-border-radius:14px 0 0 14px;-moz-border-radius:14px 0 0 14px;border-radius:14px 0 0 14px}.form-search input,.form-inline input,.form-horizontal input,.form-search textarea,.form-inline textarea,.form-horizontal textarea,.form-search select,.form-inline select,.form-horizontal select,.form-search .help-inline,.form-inline .help-inline,.form-horizontal .help-inline,.form-search .uneditable-input,.form-inline .uneditable-input,.form-horizontal .uneditable-input,.form-search .input-prepend,.form-inline .input-prepend,.form-horizontal .input-prepend,.form-search .input-append,.form-inline .input-append,.form-horizontal .input-append{display:inline-block;*display:inline;margin-bottom:0;vertical-align:middle;*zoom:1}.form-search .hide,.form-inline .hide,.form-horizontal .hide{display:none}.form-search label,.form-inline label,.form-search .btn-group,.form-inline .btn-group{display:inline-block}.form-search .input-append,.form-inline .input-append,.form-search .input-prepend,.form-inline .input-prepend{margin-bottom:0}.form-search .radio,.form-search .checkbox,.form-inline .radio,.form-inline .checkbox{padding-left:0;margin-bottom:0;vertical-align:middle}.form-search .radio input[type="radio"],.form-search .checkbox input[type="checkbox"],.form-inline .radio input[type="radio"],.form-inline .checkbox input[type="checkbox"]{float:left;margin-right:3px;margin-left:0}.control-group{margin-bottom:10px}legend+.control-group{margin-top:20px;-webkit-margin-top-collapse:separate}.form-horizontal .control-group{margin-bottom:20px;*zoom:1}.form-horizontal .control-group:before,.form-horizontal .control-group:after{display:table;line-height:0;content:""}.form-horizontal .control-group:after{clear:both}.form-horizontal .control-label{float:left;width:160px;padding-top:5px;text-align:right}.form-horizontal .controls{*display:inline-block;*padding-left:20px;margin-left:180px;*margin-left:0}.form-horizontal .controls:first-child{*padding-left:180px}.form-horizontal .help-block{margin-bottom:0}.form-horizontal input+.help-block,.form-horizontal select+.help-block,.form-horizontal textarea+.help-block,.form-horizontal .uneditable-input+.help-block,.form-horizontal .input-prepend+.help-block,.form-horizontal .input-append+.help-block{margin-top:10px}.form-horizontal .form-actions{padding-left:180px}table{max-width:100%;background-color:transparent;border-collapse:collapse;border-spacing:0}.table{width:100%;margin-bottom:20px}.table th,.table td{padding:8px;line-height:20px;text-align:left;vertical-align:top;border-top:1px solid #ddd}.table th{font-weight:bold}.table thead th{vertical-align:bottom}.table caption+thead tr:first-child th,.table caption+thead tr:first-child td,.table colgroup+thead tr:first-child th,.table colgroup+thead tr:first-child td,.table thead:first-child tr:first-child th,.table thead:first-child tr:first-child td{border-top:0}.table tbody+tbody{border-top:2px solid #ddd}.table .table{background-color:#fff}.table-condensed th,.table-condensed td{padding:4px 5px}.table-bordered{border:1px solid #ddd;border-collapse:separate;*border-collapse:collapse;border-left:0;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px}.table-bordered th,.table-bordered td{border-left:1px solid #ddd}.table-bordered caption+thead tr:first-child th,.table-bordered caption+tbody tr:first-child th,.table-bordered caption+tbody tr:first-child td,.table-bordered colgroup+thead tr:first-child th,.table-bordered colgroup+tbody tr:first-child th,.table-bordered colgroup+tbody tr:first-child td,.table-bordered thead:first-child tr:first-child th,.table-bordered tbody:first-child tr:first-child th,.table-bordered tbody:first-child tr:first-child td{border-top:0}.table-bordered thead:first-child tr:first-child>th:first-child,.table-bordered tbody:first-child tr:first-child>td:first-child{-webkit-border-top-left-radius:4px;border-top-left-radius:4px;-moz-border-radius-topleft:4px}.table-bordered thead:first-child tr:first-child>th:last-child,.table-bordered tbody:first-child tr:first-child>td:last-child{-webkit-border-top-right-radius:4px;border-top-right-radius:4px;-moz-border-radius-topright:4px}.table-bordered thead:last-child tr:last-child>th:first-child,.table-bordered tbody:last-child tr:last-child>td:first-child,.table-bordered tfoot:last-child tr:last-child>td:first-child{-webkit-border-bottom-left-radius:4px;border-bottom-left-radius:4px;-moz-border-radius-bottomleft:4px}.table-bordered thead:last-child tr:last-child>th:last-child,.table-bordered tbody:last-child tr:last-child>td:last-child,.table-bordered tfoot:last-child tr:last-child>td:last-child{-webkit-border-bottom-right-radius:4px;border-bottom-right-radius:4px;-moz-border-radius-bottomright:4px}.table-bordered tfoot+tbody:last-child tr:last-child td:first-child{-webkit-border-bottom-left-radius:0;border-bottom-left-radius:0;-moz-border-radius-bottomleft:0}.table-bordered tfoot+tbody:last-child tr:last-child td:last-child{-webkit-border-bottom-right-radius:0;border-bottom-right-radius:0;-moz-border-radius-bottomright:0}.table-bordered caption+thead tr:first-child th:first-child,.table-bordered caption+tbody tr:first-child td:first-child,.table-bordered colgroup+thead tr:first-child th:first-child,.table-bordered colgroup+tbody tr:first-child td:first-child{-webkit-border-top-left-radius:4px;border-top-left-radius:4px;-moz-border-radius-topleft:4px}.table-bordered caption+thead tr:first-child th:last-child,.table-bordered caption+tbody tr:first-child td:last-child,.table-bordered colgroup+thead tr:first-child th:last-child,.table-bordered colgroup+tbody tr:first-child td:last-child{-webkit-border-top-right-radius:4px;border-top-right-radius:4px;-moz-border-radius-topright:4px}.table-striped tbody>tr:nth-child(odd)>td,.table-striped tbody>tr:nth-child(odd)>th{background-color:#f9f9f9}.table-hover tbody tr:hover td,.table-hover tbody tr:hover th{background-color:#f5f5f5}table td[class*="span"],table th[class*="span"],.row-fluid table td[class*="span"],.row-fluid table th[class*="span"]{display:table-cell;float:none;margin-left:0}.table td.span1,.table th.span1{float:none;width:44px;margin-left:0}.table td.span2,.table th.span2{float:none;width:124px;margin-left:0}.table td.span3,.table th.span3{float:none;width:204px;margin-left:0}.table td.span4,.table th.span4{float:none;width:284px;margin-left:0}.table td.span5,.table th.span5{float:none;width:364px;margin-left:0}.table td.span6,.table th.span6{float:none;width:444px;margin-left:0}.table td.span7,.table th.span7{float:none;width:524px;margin-left:0}.table td.span8,.table th.span8{float:none;width:604px;margin-left:0}.table td.span9,.table th.span9{float:none;width:684px;margin-left:0}.table td.span10,.table th.span10{float:none;width:764px;margin-left:0}.table td.span11,.table th.span11{float:none;width:844px;margin-left:0}.table td.span12,.table th.span12{float:none;width:924px;margin-left:0}.table tbody tr.success td{background-color:#dff0d8}.table tbody tr.error td{background-color:#f2dede}.table tbody tr.warning td{background-color:#fcf8e3}.table tbody tr.info td{background-color:#d9edf7}.table-hover tbody tr.success:hover td{background-color:#d0e9c6}.table-hover tbody tr.error:hover td{background-color:#ebcccc}.table-hover tbody tr.warning:hover td{background-color:#faf2cc}.table-hover tbody tr.info:hover td{background-color:#c4e3f3}[class^="icon-"],[class*=" icon-"]{display:inline-block;width:14px;height:14px;margin-top:1px;*margin-right:.3em;line-height:14px;vertical-align:text-top;background-image:url("../img/glyphicons-halflings.png");background-position:14px 14px;background-repeat:no-repeat}.icon-white,.nav-pills>.active>a>[class^="icon-"],.nav-pills>.active>a>[class*=" icon-"],.nav-list>.active>a>[class^="icon-"],.nav-list>.active>a>[class*=" icon-"],.navbar-inverse .nav>.active>a>[class^="icon-"],.navbar-inverse .nav>.active>a>[class*=" icon-"],.dropdown-menu>li>a:hover>[class^="icon-"],.dropdown-menu>li>a:hover>[class*=" icon-"],.dropdown-menu>.active>a>[class^="icon-"],.dropdown-menu>.active>a>[class*=" icon-"],.dropdown-submenu:hover>a>[class^="icon-"],.dropdown-submenu:hover>a>[class*=" icon-"]{background-image:url("../img/glyphicons-halflings-white.png")}.icon-glass{background-position:0 0}.icon-music{background-position:-24px 0}.icon-search{background-position:-48px 0}.icon-envelope{background-position:-72px 0}.icon-heart{background-position:-96px 0}.icon-star{background-position:-120px 0}.icon-star-empty{background-position:-144px 0}.icon-user{background-position:-168px 0}.icon-film{background-position:-192px 0}.icon-th-large{background-position:-216px 0}.icon-th{background-position:-240px 0}.icon-th-list{background-position:-264px 0}.icon-ok{background-position:-288px 0}.icon-remove{background-position:-312px 0}.icon-zoom-in{background-position:-336px 0}.icon-zoom-out{background-position:-360px 0}.icon-off{background-position:-384px 0}.icon-signal{background-position:-408px 0}.icon-cog{background-position:-432px 0}.icon-trash{background-position:-456px 0}.icon-home{background-position:0 -24px}.icon-file{background-position:-24px -24px}.icon-time{background-position:-48px -24px}.icon-road{background-position:-72px -24px}.icon-download-alt{background-position:-96px -24px}.icon-download{background-position:-120px -24px}.icon-upload{background-position:-144px -24px}.icon-inbox{background-position:-168px -24px}.icon-play-circle{background-position:-192px -24px}.icon-repeat{background-position:-216px -24px}.icon-refresh{background-position:-240px -24px}.icon-list-alt{background-position:-264px -24px}.icon-lock{background-position:-287px -24px}.icon-flag{background-position:-312px -24px}.icon-headphones{background-position:-336px -24px}.icon-volume-off{background-position:-360px -24px}.icon-volume-down{background-position:-384px -24px}.icon-volume-up{background-position:-408px -24px}.icon-qrcode{background-position:-432px -24px}.icon-barcode{background-position:-456px -24px}.icon-tag{background-position:0 -48px}.icon-tags{background-position:-25px -48px}.icon-book{background-position:-48px -48px}.icon-bookmark{background-position:-72px -48px}.icon-print{background-position:-96px -48px}.icon-camera{background-position:-120px -48px}.icon-font{background-position:-144px -48px}.icon-bold{background-position:-167px -48px}.icon-italic{background-position:-192px -48px}.icon-text-height{background-position:-216px -48px}.icon-text-width{background-position:-240px -48px}.icon-align-left{background-position:-264px -48px}.icon-align-center{background-position:-288px -48px}.icon-align-right{background-position:-312px -48px}.icon-align-justify{background-position:-336px -48px}.icon-list{background-position:-360px -48px}.icon-indent-left{background-position:-384px -48px}.icon-indent-right{background-position:-408px -48px}.icon-facetime-video{background-position:-432px -48px}.icon-picture{background-position:-456px -48px}.icon-pencil{background-position:0 -72px}.icon-map-marker{background-position:-24px -72px}.icon-adjust{background-position:-48px -72px}.icon-tint{background-position:-72px -72px}.icon-edit{background-position:-96px -72px}.icon-share{background-position:-120px -72px}.icon-check{background-position:-144px -72px}.icon-move{background-position:-168px -72px}.icon-step-backward{background-position:-192px -72px}.icon-fast-backward{background-position:-216px -72px}.icon-backward{background-position:-240px -72px}.icon-play{background-position:-264px -72px}.icon-pause{background-position:-288px -72px}.icon-stop{background-position:-312px -72px}.icon-forward{background-position:-336px -72px}.icon-fast-forward{background-position:-360px -72px}.icon-step-forward{background-position:-384px -72px}.icon-eject{background-position:-408px -72px}.icon-chevron-left{background-position:-432px -72px}.icon-chevron-right{background-position:-456px -72px}.icon-plus-sign{background-position:0 -96px}.icon-minus-sign{background-position:-24px -96px}.icon-remove-sign{background-position:-48px -96px}.icon-ok-sign{background-position:-72px -96px}.icon-question-sign{background-position:-96px -96px}.icon-info-sign{background-position:-120px -96px}.icon-screenshot{background-position:-144px -96px}.icon-remove-circle{background-position:-168px -96px}.icon-ok-circle{background-position:-192px -96px}.icon-ban-circle{background-position:-216px -96px}.icon-arrow-left{background-position:-240px -96px}.icon-arrow-right{background-position:-264px -96px}.icon-arrow-up{background-position:-289px -96px}.icon-arrow-down{background-position:-312px -96px}.icon-share-alt{background-position:-336px -96px}.icon-resize-full{background-position:-360px -96px}.icon-resize-small{background-position:-384px -96px}.icon-plus{background-position:-408px -96px}.icon-minus{background-position:-433px -96px}.icon-asterisk{background-position:-456px -96px}.icon-exclamation-sign{background-position:0 -120px}.icon-gift{background-position:-24px -120px}.icon-leaf{background-position:-48px -120px}.icon-fire{background-position:-72px -120px}.icon-eye-open{background-position:-96px -120px}.icon-eye-close{background-position:-120px -120px}.icon-warning-sign{background-position:-144px -120px}.icon-plane{background-position:-168px -120px}.icon-calendar{background-position:-192px -120px}.icon-random{width:16px;background-position:-216px -120px}.icon-comment{background-position:-240px -120px}.icon-magnet{background-position:-264px -120px}.icon-chevron-up{background-position:-288px -120px}.icon-chevron-down{background-position:-313px -119px}.icon-retweet{background-position:-336px -120px}.icon-shopping-cart{background-position:-360px -120px}.icon-folder-close{background-position:-384px -120px}.icon-folder-open{width:16px;background-position:-408px -120px}.icon-resize-vertical{background-position:-432px -119px}.icon-resize-horizontal{background-position:-456px -118px}.icon-hdd{background-position:0 -144px}.icon-bullhorn{background-position:-24px -144px}.icon-bell{background-position:-48px -144px}.icon-certificate{background-position:-72px -144px}.icon-thumbs-up{background-position:-96px -144px}.icon-thumbs-down{background-position:-120px -144px}.icon-hand-right{background-position:-144px -144px}.icon-hand-left{background-position:-168px -144px}.icon-hand-up{background-position:-192px -144px}.icon-hand-down{background-position:-216px -144px}.icon-circle-arrow-right{background-position:-240px -144px}.icon-circle-arrow-left{background-position:-264px -144px}.icon-circle-arrow-up{background-position:-288px -144px}.icon-circle-arrow-down{background-position:-312px -144px}.icon-globe{background-position:-336px -144px}.icon-wrench{background-position:-360px -144px}.icon-tasks{background-position:-384px -144px}.icon-filter{background-position:-408px -144px}.icon-briefcase{background-position:-432px -144px}.icon-fullscreen{background-position:-456px -144px}.dropup,.dropdown{position:relative}.dropdown-toggle{*margin-bottom:-3px}.dropdown-toggle:active,.open .dropdown-toggle{outline:0}.caret{display:inline-block;width:0;height:0;vertical-align:top;border-top:4px solid #000;border-right:4px solid transparent;border-left:4px solid transparent;content:""}.dropdown .caret{margin-top:8px;margin-left:2px}.dropdown-menu{position:absolute;top:100%;left:0;z-index:1000;display:none;float:left;min-width:160px;padding:5px 0;margin:2px 0 0;list-style:none;background-color:#fff;border:1px solid #ccc;border:1px solid rgba(0,0,0,0.2);*border-right-width:2px;*border-bottom-width:2px;-webkit-border-radius:6px;-moz-border-radius:6px;border-radius:6px;-webkit-box-shadow:0 5px 10px rgba(0,0,0,0.2);-moz-box-shadow:0 5px 10px rgba(0,0,0,0.2);box-shadow:0 5px 10px rgba(0,0,0,0.2);-webkit-background-clip:padding-box;-moz-background-clip:padding;background-clip:padding-box}.dropdown-menu.pull-right{right:0;left:auto}.dropdown-menu .divider{*width:100%;height:1px;margin:9px 1px;*margin:-5px 0 5px;overflow:hidden;background-color:#e5e5e5;border-bottom:1px solid #fff}.dropdown-menu li>a{display:block;padding:3px 20px;clear:both;font-weight:normal;line-height:20px;color:#333;white-space:nowrap}.dropdown-menu li>a:hover,.dropdown-menu li>a:focus,.dropdown-submenu:hover>a{color:#fff;text-decoration:none;background-color:#0081c2;background-image:-moz-linear-gradient(top,#08c,#0077b3);background-image:-webkit-gradient(linear,0 0,0 100%,from(#08c),to(#0077b3));background-image:-webkit-linear-gradient(top,#08c,#0077b3);background-image:-o-linear-gradient(top,#08c,#0077b3);background-image:linear-gradient(to bottom,#08c,#0077b3);background-repeat:repeat-x;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff0088cc'',endColorstr=''#ff0077b3'',GradientType=0)}.dropdown-menu .active>a,.dropdown-menu .active>a:hover{color:#fff;text-decoration:none;background-color:#0081c2;background-image:-moz-linear-gradient(top,#08c,#0077b3);background-image:-webkit-gradient(linear,0 0,0 100%,from(#08c),to(#0077b3));background-image:-webkit-linear-gradient(top,#08c,#0077b3);background-image:-o-linear-gradient(top,#08c,#0077b3);background-image:linear-gradient(to bottom,#08c,#0077b3);background-repeat:repeat-x;outline:0;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff0088cc'',endColorstr=''#ff0077b3'',GradientType=0)}.dropdown-menu .disabled>a,.dropdown-menu .disabled>a:hover{color:#999}.dropdown-menu .disabled>a:hover{text-decoration:none;cursor:default;background-color:transparent;background-image:none;filter:progid:DXImageTransform.Microsoft.gradient(enabled=false)}.open{*z-index:1000}.open>.dropdown-menu{display:block}.pull-right>.dropdown-menu{right:0;left:auto}.dropup .caret,.navbar-fixed-bottom .dropdown .caret{border-top:0;border-bottom:4px solid #000;content:""}.dropup .dropdown-menu,.navbar-fixed-bottom .dropdown .dropdown-menu{top:auto;bottom:100%;margin-bottom:1px}.dropdown-submenu{position:relative}.dropdown-submenu>.dropdown-menu{top:0;left:100%;margin-top:-6px;margin-left:-1px;-webkit-border-radius:0 6px 6px 6px;-moz-border-radius:0 6px 6px 6px;border-radius:0 6px 6px 6px}.dropdown-submenu:hover>.dropdown-menu{display:block}.dropup .dropdown-submenu>.dropdown-menu{top:auto;bottom:0;margin-top:0;margin-bottom:-2px;-webkit-border-radius:5px 5px 5px 0;-moz-border-radius:5px 5px 5px 0;border-radius:5px 5px 5px 0}.dropdown-submenu>a:after{display:block;float:right;width:0;height:0;margin-top:5px;margin-right:-10px;border-color:transparent;border-left-color:#ccc;border-style:solid;border-width:5px 0 5px 5px;content:" "}.dropdown-submenu:hover>a:after{border-left-color:#fff}.dropdown-submenu.pull-left{float:none}.dropdown-submenu.pull-left>.dropdown-menu{left:-100%;margin-left:10px;-webkit-border-radius:6px 0 6px 6px;-moz-border-radius:6px 0 6px 6px;border-radius:6px 0 6px 6px}.dropdown .dropdown-menu .nav-header{padding-right:20px;padding-left:20px}.typeahead{z-index:1051;margin-top:2px;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px}.well{min-height:20px;padding:19px;margin-bottom:20px;background-color:#f5f5f5;border:1px solid #e3e3e3;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px;-webkit-box-shadow:inset 0 1px 1px rgba(0,0,0,0.05);-moz-box-shadow:inset 0 1px 1px rgba(0,0,0,0.05);box-shadow:inset 0 1px 1px rgba(0,0,0,0.05)}.well blockquote{border-color:#ddd;border-color:rgba(0,0,0,0.15)}.well-large{padding:24px;-webkit-border-radius:6px;-moz-border-radius:6px;border-radius:6px}.well-small{padding:9px;-webkit-border-radius:3px;-moz-border-radius:3px;border-radius:3px}.fade{opacity:0;-webkit-transition:opacity .15s linear;-moz-transition:opacity .15s linear;-o-transition:opacity .15s linear;transition:opacity .15s linear}.fade.in{opacity:1}.collapse{position:relative;height:0;overflow:hidden;-webkit-transition:height .35s ease;-moz-transition:height .35s ease;-o-transition:height .35s ease;transition:height .35s ease}.collapse.in{height:auto}.close{float:right;font-size:20px;font-weight:bold;line-height:20px;color:#000;text-shadow:0 1px 0 #fff;opacity:.2;filter:alpha(opacity=20)}.close:hover{color:#000;text-decoration:none;cursor:pointer;opacity:.4;filter:alpha(opacity=40)}button.close{padding:0;cursor:pointer;background:transparent;border:0;-webkit-appearance:none}.btn{display:inline-block;*display:inline;padding:4px 12px;margin-bottom:0;*margin-left:.3em;font-size:14px;line-height:20px;color:#333;text-align:center;text-shadow:0 1px 1px rgba(255,255,255,0.75);vertical-align:middle;cursor:pointer;background-color:#f5f5f5;*background-color:#e6e6e6;background-image:-moz-linear-gradient(top,#fff,#e6e6e6);background-image:-webkit-gradient(linear,0 0,0 100%,from(#fff),to(#e6e6e6));background-image:-webkit-linear-gradient(top,#fff,#e6e6e6);background-image:-o-linear-gradient(top,#fff,#e6e6e6);background-image:linear-gradient(to bottom,#fff,#e6e6e6);background-repeat:repeat-x;border:1px solid #bbb;*border:0;border-color:#e6e6e6 #e6e6e6 #bfbfbf;border-color:rgba(0,0,0,0.1) rgba(0,0,0,0.1) rgba(0,0,0,0.25);border-bottom-color:#a2a2a2;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ffffffff'',endColorstr=''#ffe6e6e6'',GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);*zoom:1;-webkit-box-shadow:inset 0 1px 0 rgba(255,255,255,0.2),0 1px 2px rgba(0,0,0,0.05);-moz-box-shadow:inset 0 1px 0 rgba(255,255,255,0.2),0 1px 2px rgba(0,0,0,0.05);box-shadow:inset 0 1px 0 rgba(255,255,255,0.2),0 1px 2px rgba(0,0,0,0.05)}.btn:hover,.btn:active,.btn.active,.btn.disabled,.btn[disabled]{color:#333;background-color:#e6e6e6;*background-color:#d9d9d9}.btn:active,.btn.active{background-color:#ccc \9}.btn:first-child{*margin-left:0}.btn:hover{color:#333;text-decoration:none;background-position:0 -15px;-webkit-transition:background-position .1s linear;-moz-transition:background-position .1s linear;-o-transition:background-position .1s linear;transition:background-position .1s linear}.btn:focus{outline:thin dotted #333;outline:5px auto -webkit-focus-ring-color;outline-offset:-2px}.btn.active,.btn:active{background-image:none;outline:0;-webkit-box-shadow:inset 0 2px 4px rgba(0,0,0,0.15),0 1px 2px rgba(0,0,0,0.05);-moz-box-shadow:inset 0 2px 4px rgba(0,0,0,0.15),0 1px 2px rgba(0,0,0,0.05);box-shadow:inset 0 2px 4px rgba(0,0,0,0.15),0 1px 2px rgba(0,0,0,0.05)}.btn.disabled,.btn[disabled]{cursor:default;background-image:none;opacity:.65;filter:alpha(opacity=65);-webkit-box-shadow:none;-moz-box-shadow:none;box-shadow:none}.btn-large{padding:11px 19px;font-size:17.5px;-webkit-border-radius:6px;-moz-border-radius:6px;border-radius:6px}.btn-large [class^="icon-"],.btn-large [class*=" icon-"]{margin-top:4px}.btn-small{padding:2px 10px;font-size:11.9px;-webkit-border-radius:3px;-moz-border-radius:3px;border-radius:3px}.btn-small [class^="icon-"],.btn-small [class*=" icon-"]{margin-top:0}.btn-mini [class^="icon-"],.btn-mini [class*=" icon-"]{margin-top:-1px}.btn-mini{padding:0 6px;font-size:10.5px;-webkit-border-radius:3px;-moz-border-radius:3px;border-radius:3px}.btn-block{display:block;width:100%;padding-right:0;padding-left:0;-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box}.btn-block+.btn-block{margin-top:5px}input[type="submit"].btn-block,input[type="reset"].btn-block,input[type="button"].btn-block{width:100%}.btn-primary.active,.btn-warning.active,.btn-danger.active,.btn-success.active,.btn-info.active,.btn-inverse.active{color:rgba(255,255,255,0.75)}.btn{border-color:#c5c5c5;border-color:rgba(0,0,0,0.15) rgba(0,0,0,0.15) rgba(0,0,0,0.25)}.btn-primary{color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.25);background-color:#006dcc;*background-color:#04c;background-image:-moz-linear-gradient(top,#08c,#04c);background-image:-webkit-gradient(linear,0 0,0 100%,from(#08c),to(#04c));background-image:-webkit-linear-gradient(top,#08c,#04c);background-image:-o-linear-gradient(top,#08c,#04c);background-image:linear-gradient(to bottom,#08c,#04c);background-repeat:repeat-x;border-color:#04c #04c #002a80;border-color:rgba(0,0,0,0.1) rgba(0,0,0,0.1) rgba(0,0,0,0.25);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff0088cc'',endColorstr=''#ff0044cc'',GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false)}.btn-primary:hover,.btn-primary:active,.btn-primary.active,.btn-primary.disabled,.btn-primary[disabled]{color:#fff;background-color:#04c;*background-color:#003bb3}.btn-primary:active,.btn-primary.active{background-color:#039 \9}.btn-warning{color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.25);background-color:#faa732;*background-color:#f89406;background-image:-moz-linear-gradient(top,#fbb450,#f89406);background-image:-webkit-gradient(linear,0 0,0 100%,from(#fbb450),to(#f89406));background-image:-webkit-linear-gradient(top,#fbb450,#f89406);background-image:-o-linear-gradient(top,#fbb450,#f89406);background-image:linear-gradient(to bottom,#fbb450,#f89406);background-repeat:repeat-x;border-color:#f89406 #f89406 #ad6704;border-color:rgba(0,0,0,0.1) rgba(0,0,0,0.1) rgba(0,0,0,0.25);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#fffbb450'',endColorstr=''#fff89406'',GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false)}.btn-warning:hover,.btn-warning:active,.btn-warning.active,.btn-warning.disabled,.btn-warning[disabled]{color:#fff;background-color:#f89406;*background-color:#df8505}.btn-warning:active,.btn-warning.active{background-color:#c67605 \9}.btn-danger{color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.25);background-color:#da4f49;*background-color:#bd362f;background-image:-moz-linear-gradient(top,#ee5f5b,#bd362f);background-image:-webkit-gradient(linear,0 0,0 100%,from(#ee5f5b),to(#bd362f));background-image:-webkit-linear-gradient(top,#ee5f5b,#bd362f);background-image:-o-linear-gradient(top,#ee5f5b,#bd362f);background-image:linear-gradient(to bottom,#ee5f5b,#bd362f);background-repeat:repeat-x;border-color:#bd362f #bd362f #802420;border-color:rgba(0,0,0,0.1) rgba(0,0,0,0.1) rgba(0,0,0,0.25);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ffee5f5b'',endColorstr=''#ffbd362f'',GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false)}.btn-danger:hover,.btn-danger:active,.btn-danger.active,.btn-danger.disabled,.btn-danger[disabled]{color:#fff;background-color:#bd362f;*background-color:#a9302a}.btn-danger:active,.btn-danger.active{background-color:#942a25 \9}.btn-success{color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.25);background-color:#5bb75b;*background-color:#51a351;background-image:-moz-linear-gradient(top,#62c462,#51a351);background-image:-webkit-gradient(linear,0 0,0 100%,from(#62c462),to(#51a351));background-image:-webkit-linear-gradient(top,#62c462,#51a351);background-image:-o-linear-gradient(top,#62c462,#51a351);background-image:linear-gradient(to bottom,#62c462,#51a351);background-repeat:repeat-x;border-color:#51a351 #51a351 #387038;border-color:rgba(0,0,0,0.1) rgba(0,0,0,0.1) rgba(0,0,0,0.25);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff62c462'',endColorstr=''#ff51a351'',GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false)}.btn-success:hover,.btn-success:active,.btn-success.active,.btn-success.disabled,.btn-success[disabled]{color:#fff;background-color:#51a351;*background-color:#499249}.btn-success:active,.btn-success.active{background-color:#408140 \9}.btn-info{color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.25);background-color:#49afcd;*background-color:#2f96b4;background-image:-moz-linear-gradient(top,#5bc0de,#2f96b4);background-image:-webkit-gradient(linear,0 0,0 100%,from(#5bc0de),to(#2f96b4));background-image:-webkit-linear-gradient(top,#5bc0de,#2f96b4);background-image:-o-linear-gradient(top,#5bc0de,#2f96b4);background-image:linear-gradient(to bottom,#5bc0de,#2f96b4);background-repeat:repeat-x;border-color:#2f96b4 #2f96b4 #1f6377;border-color:rgba(0,0,0,0.1) rgba(0,0,0,0.1) rgba(0,0,0,0.25);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff5bc0de'',endColorstr=''#ff2f96b4'',GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false)}.btn-info:hover,.btn-info:active,.btn-info.active,.btn-info.disabled,.btn-info[disabled]{color:#fff;background-color:#2f96b4;*background-color:#2a85a0}.btn-info:active,.btn-info.active{background-color:#24748c \9}.btn-inverse{color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.25);background-color:#363636;*background-color:#222;background-image:-moz-linear-gradient(top,#444,#222);background-image:-webkit-gradient(linear,0 0,0 100%,from(#444),to(#222));background-image:-webkit-linear-gradient(top,#444,#222);background-image:-o-linear-gradient(top,#444,#222);background-image:linear-gradient(to bottom,#444,#222);background-repeat:repeat-x;border-color:#222 #222 #000;border-color:rgba(0,0,0,0.1) rgba(0,0,0,0.1) rgba(0,0,0,0.25);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff444444'',endColorstr=''#ff222222'',GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false)}.btn-inverse:hover,.btn-inverse:active,.btn-inverse.active,.btn-inverse.disabled,.btn-inverse[disabled]{color:#fff;background-color:#222;*background-color:#151515}.btn-inverse:active,.btn-inverse.active{background-color:#080808 \9}button.btn,input[type="submit"].btn{*padding-top:3px;*padding-bottom:3px}button.btn::-moz-focus-inner,input[type="submit"].btn::-moz-focus-inner{padding:0;border:0}button.btn.btn-large,input[type="submit"].btn.btn-large{*padding-top:7px;*padding-bottom:7px}button.btn.btn-small,input[type="submit"].btn.btn-small{*padding-top:3px;*padding-bottom:3px}button.btn.btn-mini,input[type="submit"].btn.btn-mini{*padding-top:1px;*padding-bottom:1px}.btn-link,.btn-link:active,.btn-link[disabled]{background-color:transparent;background-image:none;-webkit-box-shadow:none;-moz-box-shadow:none;box-shadow:none}.btn-link{color:#08c;cursor:pointer;border-color:transparent;-webkit-border-radius:0;-moz-border-radius:0;border-radius:0}.btn-link:hover{color:#005580;text-decoration:underline;background-color:transparent}.btn-link[disabled]:hover{color:#333;text-decoration:none}.btn-group{position:relative;display:inline-block;*display:inline;*margin-left:.3em;font-size:0;white-space:nowrap;vertical-align:middle;*zoom:1}.btn-group:first-child{*margin-left:0}.btn-group+.btn-group{margin-left:5px}.btn-toolbar{margin-top:10px;margin-bottom:10px;font-size:0}.btn-toolbar>.btn+.btn,.btn-toolbar>.btn-group+.btn,.btn-toolbar>.btn+.btn-group{margin-left:5px}.btn-group>.btn{position:relative;-webkit-border-radius:0;-moz-border-radius:0;border-radius:0}.btn-group>.btn+.btn{margin-left:-1px}.btn-group>.btn,.btn-group>.dropdown-menu,.btn-group>.popover{font-size:14px}.btn-group>.btn-mini{font-size:10.5px}.btn-group>.btn-small{font-size:11.9px}.btn-group>.btn-large{font-size:17.5px}.btn-group>.btn:first-child{margin-left:0;-webkit-border-bottom-left-radius:4px;border-bottom-left-radius:4px;-webkit-border-top-left-radius:4px;border-top-left-radius:4px;-moz-border-radius-bottomleft:4px;-moz-border-radius-topleft:4px}.btn-group>.btn:last-child,.btn-group>.dropdown-toggle{-webkit-border-top-right-radius:4px;border-top-right-radius:4px;-webkit-border-bottom-right-radius:4px;border-bottom-right-radius:4px;-moz-border-radius-topright:4px;-moz-border-radius-bottomright:4px}.btn-group>.btn.large:first-child{margin-left:0;-webkit-border-bottom-left-radius:6px;border-bottom-left-radius:6px;-webkit-border-top-left-radius:6px;border-top-left-radius:6px;-moz-border-radius-bottomleft:6px;-moz-border-radius-topleft:6px}.btn-group>.btn.large:last-child,.btn-group>.large.dropdown-toggle{-webkit-border-top-right-radius:6px;border-top-right-radius:6px;-webkit-border-bottom-right-radius:6px;border-bottom-right-radius:6px;-moz-border-radius-topright:6px;-moz-border-radius-bottomright:6px}.btn-group>.btn:hover,.btn-group>.btn:focus,.btn-group>.btn:active,.btn-group>.btn.active{z-index:2}.btn-group .dropdown-toggle:active,.btn-group.open .dropdown-toggle{outline:0}.btn-group>.btn+.dropdown-toggle{*padding-top:5px;padding-right:8px;*padding-bottom:5px;padding-left:8px;-webkit-box-shadow:inset 1px 0 0 rgba(255,255,255,0.125),inset 0 1px 0 rgba(255,255,255,0.2),0 1px 2px rgba(0,0,0,0.05);-moz-box-shadow:inset 1px 0 0 rgba(255,255,255,0.125),inset 0 1px 0 rgba(255,255,255,0.2),0 1px 2px rgba(0,0,0,0.05);box-shadow:inset 1px 0 0 rgba(255,255,255,0.125),inset 0 1px 0 rgba(255,255,255,0.2),0 1px 2px rgba(0,0,0,0.05)}.btn-group>.btn-mini+.dropdown-toggle{*padding-top:2px;padding-right:5px;*padding-bottom:2px;padding-left:5px}.btn-group>.btn-small+.dropdown-toggle{*padding-top:5px;*padding-bottom:4px}.btn-group>.btn-large+.dropdown-toggle{*padding-top:7px;padding-right:12px;*padding-bottom:7px;padding-left:12px}.btn-group.open .dropdown-toggle{background-image:none;-webkit-box-shadow:inset 0 2px 4px rgba(0,0,0,0.15),0 1px 2px rgba(0,0,0,0.05);-moz-box-shadow:inset 0 2px 4px rgba(0,0,0,0.15),0 1px 2px rgba(0,0,0,0.05);box-shadow:inset 0 2px 4px rgba(0,0,0,0.15),0 1px 2px rgba(0,0,0,0.05)}.btn-group.open .btn.dropdown-toggle{background-color:#e6e6e6}.btn-group.open .btn-primary.dropdown-toggle{background-color:#04c}.btn-group.open .btn-warning.dropdown-toggle{background-color:#f89406}.btn-group.open .btn-danger.dropdown-toggle{background-color:#bd362f}.btn-group.open .btn-success.dropdown-toggle{background-color:#51a351}.btn-group.open .btn-info.dropdown-toggle{background-color:#2f96b4}.btn-group.open .btn-inverse.dropdown-toggle{background-color:#222}.btn .caret{margin-top:8px;margin-left:0}.btn-mini .caret,.btn-small .caret,.btn-large .caret{margin-top:6px}.btn-large .caret{border-top-width:5px;border-right-width:5px;border-left-width:5px}.dropup .btn-large .caret{border-bottom-width:5px}.btn-primary .caret,.btn-warning .caret,.btn-danger .caret,.btn-info .caret,.btn-success .caret,.btn-inverse .caret{border-top-color:#fff;border-bottom-color:#fff}.btn-group-vertical{display:inline-block;*display:inline;*zoom:1}.btn-group-vertical>.btn{display:block;float:none;max-width:100%;-webkit-border-radius:0;-moz-border-radius:0;border-radius:0}.btn-group-vertical>.btn+.btn{margin-top:-1px;margin-left:0}.btn-group-vertical>.btn:first-child{-webkit-border-radius:4px 4px 0 0;-moz-border-radius:4px 4px 0 0;border-radius:4px 4px 0 0}.btn-group-vertical>.btn:last-child{-webkit-border-radius:0 0 4px 4px;-moz-border-radius:0 0 4px 4px;border-radius:0 0 4px 4px}.btn-group-vertical>.btn-large:first-child{-webkit-border-radius:6px 6px 0 0;-moz-border-radius:6px 6px 0 0;border-radius:6px 6px 0 0}.btn-group-vertical>.btn-large:last-child{-webkit-border-radius:0 0 6px 6px;-moz-border-radius:0 0 6px 6px;border-radius:0 0 6px 6px}.alert{padding:8px 35px 8px 14px;margin-bottom:20px;text-shadow:0 1px 0 rgba(255,255,255,0.5);background-color:#fcf8e3;border:1px solid #fbeed5;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px}.alert,.alert h4{color:#c09853}.alert h4{margin:0}.alert .close{position:relative;top:-2px;right:-21px;line-height:20px}.alert-success{color:#468847;background-color:#dff0d8;border-color:#d6e9c6}.alert-success h4{color:#468847}.alert-danger,.alert-error{color:#b94a48;background-color:#f2dede;border-color:#eed3d7}.alert-danger h4,.alert-error h4{color:#b94a48}.alert-info{color:#3a87ad;background-color:#d9edf7;border-color:#bce8f1}.alert-info h4{color:#3a87ad}.alert-block{padding-top:14px;padding-bottom:14px}.alert-block>p,.alert-block>ul{margin-bottom:0}.alert-block p+p{margin-top:5px}.nav{margin-bottom:20px;margin-left:0;list-style:none}.nav>li>a{display:block}.nav>li>a:hover{text-decoration:none;background-color:#eee}.nav>li>a>img{max-width:none}.nav>.pull-right{float:right}.nav-header{display:block;padding:3px 15px;font-size:11px;font-weight:bold;line-height:20px;color:#999;text-shadow:0 1px 0 rgba(255,255,255,0.5);text-transform:uppercase}.nav li+.nav-header{margin-top:9px}.nav-list{padding-right:15px;padding-left:15px;margin-bottom:0}.nav-list>li>a,.nav-list .nav-header{margin-right:-15px;margin-left:-15px;text-shadow:0 1px 0 rgba(255,255,255,0.5)}.nav-list>li>a{padding:3px 15px}.nav-list>.active>a,.nav-list>.active>a:hover{color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.2);background-color:#08c}.nav-list [class^="icon-"],.nav-list [class*=" icon-"]{margin-right:2px}.nav-list .divider{*width:100%;height:1px;margin:9px 1px;*margin:-5px 0 5px;overflow:hidden;background-color:#e5e5e5;border-bottom:1px solid #fff}.nav-tabs,.nav-pills{*zoom:1}.nav-tabs:before,.nav-pills:before,.nav-tabs:after,.nav-pills:after{display:table;line-height:0;content:""}.nav-tabs:after,.nav-pills:after{clear:both}.nav-tabs>li,.nav-pills>li{float:left}.nav-tabs>li>a,.nav-pills>li>a{padding-right:12px;padding-left:12px;margin-right:2px;line-height:14px}.nav-tabs{border-bottom:1px solid #ddd}.nav-tabs>li{margin-bottom:-1px}.nav-tabs>li>a{padding-top:8px;padding-bottom:8px;line-height:20px;border:1px solid transparent;-webkit-border-radius:4px 4px 0 0;-moz-border-radius:4px 4px 0 0;border-radius:4px 4px 0 0}.nav-tabs>li>a:hover{border-color:#eee #eee #ddd}.nav-tabs>.active>a,.nav-tabs>.active>a:hover{color:#555;cursor:default;background-color:#fff;border:1px solid #ddd;border-bottom-color:transparent}.nav-pills>li>a{padding-top:8px;padding-bottom:8px;margin-top:2px;margin-bottom:2px;-webkit-border-radius:5px;-moz-border-radius:5px;border-radius:5px}.nav-pills>.active>a,.nav-pills>.active>a:hover{color:#fff;background-color:#08c}.nav-stacked>li{float:none}.nav-stacked>li>a{margin-right:0}.nav-tabs.nav-stacked{border-bottom:0}.nav-tabs.nav-stacked>li>a{border:1px solid #ddd;-webkit-border-radius:0;-moz-border-radius:0;border-radius:0}.nav-tabs.nav-stacked>li:first-child>a{-webkit-border-top-right-radius:4px;border-top-right-radius:4px;-webkit-border-top-left-radius:4px;border-top-left-radius:4px;-moz-border-radius-topright:4px;-moz-border-radius-topleft:4px}.nav-tabs.nav-stacked>li:last-child>a{-webkit-border-bottom-right-radius:4px;border-bottom-right-radius:4px;-webkit-border-bottom-left-radius:4px;border-bottom-left-radius:4px;-moz-border-radius-bottomright:4px;-moz-border-radius-bottomleft:4px}.nav-tabs.nav-stacked>li>a:hover{z-index:2;border-color:#ddd}.nav-pills.nav-stacked>li>a{margin-bottom:3px}.nav-pills.nav-stacked>li:last-child>a{margin-bottom:1px}.nav-tabs .dropdown-menu{-webkit-border-radius:0 0 6px 6px;-moz-border-radius:0 0 6px 6px;border-radius:0 0 6px 6px}.nav-pills .dropdown-menu{-webkit-border-radius:6px;-moz-border-radius:6px;border-radius:6px}.nav .dropdown-toggle .caret{margin-top:6px;border-top-color:#08c;border-bottom-color:#08c}.nav .dropdown-toggle:hover .caret{border-top-color:#005580;border-bottom-color:#005580}.nav-tabs .dropdown-toggle .caret{margin-top:8px}.nav .active .dropdown-toggle .caret{border-top-color:#fff;border-bottom-color:#fff}.nav-tabs .active .dropdown-toggle .caret{border-top-color:#555;border-bottom-color:#555}.nav>.dropdown.active>a:hover{cursor:pointer}.nav-tabs .open .dropdown-toggle,.nav-pills .open .dropdown-toggle,.nav>li.dropdown.open.active>a:hover{color:#fff;background-color:#999;border-color:#999}.nav li.dropdown.open .caret,.nav li.dropdown.open.active .caret,.nav li.dropdown.open a:hover .caret{border-top-color:#fff;border-bottom-color:#fff;opacity:1;filter:alpha(opacity=100)}.tabs-stacked .open>a:hover{border-color:#999}.tabbable{*zoom:1}.tabbable:before,.tabbable:after{display:table;line-height:0;content:""}.tabbable:after{clear:both}.tab-content{overflow:auto}.tabs-below>.nav-tabs,.tabs-right>.nav-tabs,.tabs-left>.nav-tabs{border-bottom:0}.tab-content>.tab-pane,.pill-content>.pill-pane{display:none}.tab-content>.active,.pill-content>.active{display:block}.tabs-below>.nav-tabs{border-top:1px solid #ddd}.tabs-below>.nav-tabs>li{margin-top:-1px;margin-bottom:0}.tabs-below>.nav-tabs>li>a{-webkit-border-radius:0 0 4px 4px;-moz-border-radius:0 0 4px 4px;border-radius:0 0 4px 4px}.tabs-below>.nav-tabs>li>a:hover{border-top-color:#ddd;border-bottom-color:transparent}.tabs-below>.nav-tabs>.active>a,.tabs-below>.nav-tabs>.active>a:hover{border-color:transparent #ddd #ddd #ddd}.tabs-left>.nav-tabs>li,.tabs-right>.nav-tabs>li{float:none}.tabs-left>.nav-tabs>li>a,.tabs-right>.nav-tabs>li>a{min-width:74px;margin-right:0;margin-bottom:3px}.tabs-left>.nav-tabs{float:left;margin-right:19px;border-right:1px solid #ddd}.tabs-left>.nav-tabs>li>a{margin-right:-1px;-webkit-border-radius:4px 0 0 4px;-moz-border-radius:4px 0 0 4px;border-radius:4px 0 0 4px}.tabs-left>.nav-tabs>li>a:hover{border-color:#eee #ddd #eee #eee}.tabs-left>.nav-tabs .active>a,.tabs-left>.nav-tabs .active>a:hover{border-color:#ddd transparent #ddd #ddd;*border-right-color:#fff}.tabs-right>.nav-tabs{float:right;margin-left:19px;border-left:1px solid #ddd}.tabs-right>.nav-tabs>li>a{margin-left:-1px;-webkit-border-radius:0 4px 4px 0;-moz-border-radius:0 4px 4px 0;border-radius:0 4px 4px 0}.tabs-right>.nav-tabs>li>a:hover{border-color:#eee #eee #eee #ddd}.tabs-right>.nav-tabs .active>a,.tabs-right>.nav-tabs .active>a:hover{border-color:#ddd #ddd #ddd transparent;*border-left-color:#fff}.nav>.disabled>a{color:#999}.nav>.disabled>a:hover{text-decoration:none;cursor:default;background-color:transparent}.navbar{*position:relative;*z-index:2;margin-bottom:20px;overflow:visible}.navbar-inner{min-height:40px;padding-right:20px;padding-left:20px;background-color:#fafafa;background-image:-moz-linear-gradient(top,#fff,#f2f2f2);background-image:-webkit-gradient(linear,0 0,0 100%,from(#fff),to(#f2f2f2));background-image:-webkit-linear-gradient(top,#fff,#f2f2f2);background-image:-o-linear-gradient(top,#fff,#f2f2f2);background-image:linear-gradient(to bottom,#fff,#f2f2f2);background-repeat:repeat-x;border:1px solid #d4d4d4;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ffffffff'',endColorstr=''#fff2f2f2'',GradientType=0);*zoom:1;-webkit-box-shadow:0 1px 4px rgba(0,0,0,0.065);-moz-box-shadow:0 1px 4px rgba(0,0,0,0.065);box-shadow:0 1px 4px rgba(0,0,0,0.065)}.navbar-inner:before,.navbar-inner:after{display:table;line-height:0;content:""}.navbar-inner:after{clear:both}.navbar .container{width:auto}.nav-collapse.collapse{height:auto;overflow:visible}.navbar .brand{display:block;float:left;padding:10px 20px 10px;margin-left:-20px;font-size:20px;font-weight:200;color:#777;text-shadow:0 1px 0 #fff}.navbar .brand:hover{text-decoration:none}.navbar-text{margin-bottom:0;line-height:40px;color:#777}.navbar-link{color:#777}.navbar-link:hover{color:#333}.navbar .divider-vertical{height:40px;margin:0 9px;border-right:1px solid #fff;border-left:1px solid #f2f2f2}.navbar .btn,.navbar .btn-group{margin-top:5px}.navbar .btn-group .btn,.navbar .input-prepend .btn,.navbar .input-append .btn{margin-top:0}.navbar-form{margin-bottom:0;*zoom:1}.navbar-form:before,.navbar-form:after{display:table;line-height:0;content:""}.navbar-form:after{clear:both}.navbar-form input,.navbar-form select,.navbar-form .radio,.navbar-form .checkbox{margin-top:5px}.navbar-form input,.navbar-form select,.navbar-form .btn{display:inline-block;margin-bottom:0}.navbar-form input[type="image"],.navbar-form input[type="checkbox"],.navbar-form input[type="radio"]{margin-top:3px}.navbar-form .input-append,.navbar-form .input-prepend{margin-top:5px;white-space:nowrap}.navbar-form .input-append input,.navbar-form .input-prepend input{margin-top:0}.navbar-search{position:relative;float:left;margin-top:5px;margin-bottom:0}.navbar-search .search-query{padding:4px 14px;margin-bottom:0;font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;font-size:13px;font-weight:normal;line-height:1;-webkit-border-radius:15px;-moz-border-radius:15px;border-radius:15px}.navbar-static-top{position:static;margin-bottom:0}.navbar-static-top .navbar-inner{-webkit-border-radius:0;-moz-border-radius:0;border-radius:0}.navbar-fixed-top,.navbar-fixed-bottom{position:fixed;right:0;left:0;z-index:1030;margin-bottom:0}.navbar-fixed-top .navbar-inner,.navbar-static-top .navbar-inner{border-width:0 0 1px}.navbar-fixed-bottom .navbar-inner{border-width:1px 0 0}.navbar-fixed-top .navbar-inner,.navbar-fixed-bottom .navbar-inner{padding-right:0;padding-left:0;-webkit-border-radius:0;-moz-border-radius:0;border-radius:0}.navbar-static-top .container,.navbar-fixed-top .container,.navbar-fixed-bottom .container{width:940px}.navbar-fixed-top{top:0}.navbar-fixed-top .navbar-inner,.navbar-static-top .navbar-inner{-webkit-box-shadow:0 1px 10px rgba(0,0,0,0.1);-moz-box-shadow:0 1px 10px rgba(0,0,0,0.1);box-shadow:0 1px 10px rgba(0,0,0,0.1)}.navbar-fixed-bottom{bottom:0}.navbar-fixed-bottom .navbar-inner{-webkit-box-shadow:0 -1px 10px rgba(0,0,0,0.1);-moz-box-shadow:0 -1px 10px rgba(0,0,0,0.1);box-shadow:0 -1px 10px rgba(0,0,0,0.1)}.navbar .nav{position:relative;left:0;display:block;float:left;margin:0 10px 0 0}.navbar .nav.pull-right{float:right;margin-right:0}.navbar .nav>li{float:left}.navbar .nav>li>a{float:none;padding:10px 15px 10px;color:#777;text-decoration:none;text-shadow:0 1px 0 #fff}.navbar .nav .dropdown-toggle .caret{margin-top:8px}.navbar .nav>li>a:focus,.navbar .nav>li>a:hover{color:#333;text-decoration:none;background-color:transparent}.navbar .nav>.active>a,.navbar .nav>.active>a:hover,.navbar .nav>.active>a:focus{color:#555;text-decoration:none;background-color:#e5e5e5;-webkit-box-shadow:inset 0 3px 8px rgba(0,0,0,0.125);-moz-box-shadow:inset 0 3px 8px rgba(0,0,0,0.125);box-shadow:inset 0 3px 8px rgba(0,0,0,0.125)}.navbar .btn-navbar{display:none;float:right;padding:7px 10px;margin-right:5px;margin-left:5px;color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.25);background-color:#ededed;*background-color:#e5e5e5;background-image:-moz-linear-gradient(top,#f2f2f2,#e5e5e5);background-image:-webkit-gradient(linear,0 0,0 100%,from(#f2f2f2),to(#e5e5e5));background-image:-webkit-linear-gradient(top,#f2f2f2,#e5e5e5);background-image:-o-linear-gradient(top,#f2f2f2,#e5e5e5);background-image:linear-gradient(to bottom,#f2f2f2,#e5e5e5);background-repeat:repeat-x;border-color:#e5e5e5 #e5e5e5 #bfbfbf;border-color:rgba(0,0,0,0.1) rgba(0,0,0,0.1) rgba(0,0,0,0.25);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#fff2f2f2'',endColorstr=''#ffe5e5e5'',GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false);-webkit-box-shadow:inset 0 1px 0 rgba(255,255,255,0.1),0 1px 0 rgba(255,255,255,0.075);-moz-box-shadow:inset 0 1px 0 rgba(255,255,255,0.1),0 1px 0 rgba(255,255,255,0.075);box-shadow:inset 0 1px 0 rgba(255,255,255,0.1),0 1px 0 rgba(255,255,255,0.075)}.navbar .btn-navbar:hover,.navbar .btn-navbar:active,.navbar .btn-navbar.active,.navbar .btn-navbar.disabled,.navbar .btn-navbar[disabled]{color:#fff;background-color:#e5e5e5;*background-color:#d9d9d9}.navbar .btn-navbar:active,.navbar .btn-navbar.active{background-color:#ccc \9}.navbar .btn-navbar .icon-bar{display:block;width:18px;height:2px;background-color:#f5f5f5;-webkit-border-radius:1px;-moz-border-radius:1px;border-radius:1px;-webkit-box-shadow:0 1px 0 rgba(0,0,0,0.25);-moz-box-shadow:0 1px 0 rgba(0,0,0,0.25);box-shadow:0 1px 0 rgba(0,0,0,0.25)}.btn-navbar .icon-bar+.icon-bar{margin-top:3px}.navbar .nav>li>.dropdown-menu:before{position:absolute;top:-7px;left:9px;display:inline-block;border-right:7px solid transparent;border-bottom:7px solid #ccc;border-left:7px solid transparent;border-bottom-color:rgba(0,0,0,0.2);content:''''}.navbar .nav>li>.dropdown-menu:after{position:absolute;top:-6px;left:10px;display:inline-block;border-right:6px solid transparent;border-bottom:6px solid #fff;border-left:6px solid transparent;content:''''}.navbar-fixed-bottom .nav>li>.dropdown-menu:before{top:auto;bottom:-7px;border-top:7px solid #ccc;border-bottom:0;border-top-color:rgba(0,0,0,0.2)}.navbar-fixed-bottom .nav>li>.dropdown-menu:after{top:auto;bottom:-6px;border-top:6px solid #fff;border-bottom:0}.navbar .nav li.dropdown>a:hover .caret{border-top-color:#555;border-bottom-color:#555}.navbar .nav li.dropdown.open>.dropdown-toggle,.navbar .nav li.dropdown.active>.dropdown-toggle,.navbar .nav li.dropdown.open.active>.dropdown-toggle{color:#555;background-color:#e5e5e5}.navbar .nav li.dropdown>.dropdown-toggle .caret{border-top-color:#777;border-bottom-color:#777}.navbar .nav li.dropdown.open>.dropdown-toggle .caret,.navbar .nav li.dropdown.active>.dropdown-toggle .caret,.navbar .nav li.dropdown.open.active>.dropdown-toggle .caret{border-top-color:#555;border-bottom-color:#555}.navbar .pull-right>li>.dropdown-menu,.navbar .nav>li>.dropdown-menu.pull-right{right:0;left:auto}.navbar .pull-right>li>.dropdown-menu:before,.navbar .nav>li>.dropdown-menu.pull-right:before{right:12px;left:auto}.navbar .pull-right>li>.dropdown-menu:after,.navbar .nav>li>.dropdown-menu.pull-right:after{right:13px;left:auto}.navbar .pull-right>li>.dropdown-menu .dropdown-menu,.navbar .nav>li>.dropdown-menu.pull-right .dropdown-menu{right:100%;left:auto;margin-right:-1px;margin-left:0;-webkit-border-radius:6px 0 6px 6px;-moz-border-radius:6px 0 6px 6px;border-radius:6px 0 6px 6px}.navbar-inverse .navbar-inner{background-color:#1b1b1b;background-image:-moz-linear-gradient(top,#222,#111);background-image:-webkit-gradient(linear,0 0,0 100%,from(#222),to(#111));background-image:-webkit-linear-gradient(top,#222,#111);background-image:-o-linear-gradient(top,#222,#111);background-image:linear-gradient(to bottom,#222,#111);background-repeat:repeat-x;border-color:#252525;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff222222'',endColorstr=''#ff111111'',GradientType=0)}.navbar-inverse .brand,.navbar-inverse .nav>li>a{color:#999;text-shadow:0 -1px 0 rgba(0,0,0,0.25)}.navbar-inverse .brand:hover,.navbar-inverse .nav>li>a:hover{color:#fff}.navbar-inverse .brand{color:#999}.navbar-inverse .navbar-text{color:#999}.navbar-inverse .nav>li>a:focus,.navbar-inverse .nav>li>a:hover{color:#fff;background-color:transparent}.navbar-inverse .nav .active>a,.navbar-inverse .nav .active>a:hover,.navbar-inverse .nav .active>a:focus{color:#fff;background-color:#111}.navbar-inverse .navbar-link{color:#999}.navbar-inverse .navbar-link:hover{color:#fff}.navbar-inverse .divider-vertical{border-right-color:#222;border-left-color:#111}.navbar-inverse .nav li.dropdown.open>.dropdown-toggle,.navbar-inverse .nav li.dropdown.active>.dropdown-toggle,.navbar-inverse .nav li.dropdown.open.active>.dropdown-toggle{color:#fff;background-color:#111}.navbar-inverse .nav li.dropdown>a:hover .caret{border-top-color:#fff;border-bottom-color:#fff}.navbar-inverse .nav li.dropdown>.dropdown-toggle .caret{border-top-color:#999;border-bottom-color:#999}.navbar-inverse .nav li.dropdown.open>.dropdown-toggle .caret,.navbar-inverse .nav li.dropdown.active>.dropdown-toggle .caret,.navbar-inverse .nav li.dropdown.open.active>.dropdown-toggle .caret{border-top-color:#fff;border-bottom-color:#fff}.navbar-inverse .navbar-search .search-query{color:#fff;background-color:#515151;border-color:#111;-webkit-box-shadow:inset 0 1px 2px rgba(0,0,0,0.1),0 1px 0 rgba(255,255,255,0.15);-moz-box-shadow:inset 0 1px 2px rgba(0,0,0,0.1),0 1px 0 rgba(255,255,255,0.15);box-shadow:inset 0 1px 2px rgba(0,0,0,0.1),0 1px 0 rgba(255,255,255,0.15);-webkit-transition:none;-moz-transition:none;-o-transition:none;transition:none}.navbar-inverse .navbar-search .search-query:-moz-placeholder{color:#ccc}.navbar-inverse .navbar-search .search-query:-ms-input-placeholder{color:#ccc}.navbar-inverse .navbar-search .search-query::-webkit-input-placeholder{color:#ccc}.navbar-inverse .navbar-search .search-query:focus,.navbar-inverse .navbar-search .search-query.focused{padding:5px 15px;color:#333;text-shadow:0 1px 0 #fff;background-color:#fff;border:0;outline:0;-webkit-box-shadow:0 0 3px rgba(0,0,0,0.15);-moz-box-shadow:0 0 3px rgba(0,0,0,0.15);box-shadow:0 0 3px rgba(0,0,0,0.15)}.navbar-inverse .btn-navbar{color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.25);background-color:#0e0e0e;*background-color:#040404;background-image:-moz-linear-gradient(top,#151515,#040404);background-image:-webkit-gradient(linear,0 0,0 100%,from(#151515),to(#040404));background-image:-webkit-linear-gradient(top,#151515,#040404);background-image:-o-linear-gradient(top,#151515,#040404);background-image:linear-gradient(to bottom,#151515,#040404);background-repeat:repeat-x;border-color:#040404 #040404 #000;border-color:rgba(0,0,0,0.1) rgba(0,0,0,0.1) rgba(0,0,0,0.25);filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff151515'',endColorstr=''#ff040404'',GradientType=0);filter:progid:DXImageTransform.Microsoft.gradient(enabled=false)}.navbar-inverse .btn-navbar:hover,.navbar-inverse .btn-navbar:active,.navbar-inverse .btn-navbar.active,.navbar-inverse .btn-navbar.disabled,.navbar-inverse .btn-navbar[disabled]{color:#fff;background-color:#040404;*background-color:#000}.navbar-inverse .btn-navbar:active,.navbar-inverse .btn-navbar.active{background-color:#000 \9}.breadcrumb{padding:8px 15px;margin:0 0 20px;list-style:none;background-color:#f5f5f5;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px}.breadcrumb>li{display:inline-block;*display:inline;text-shadow:0 1px 0 #fff;*zoom:1}.breadcrumb>li>.divider{padding:0 5px;color:#ccc}.breadcrumb>.active{color:#999}.pagination{margin:20px 0}.pagination ul{display:inline-block;*display:inline;margin-bottom:0;margin-left:0;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px;*zoom:1;-webkit-box-shadow:0 1px 2px rgba(0,0,0,0.05);-moz-box-shadow:0 1px 2px rgba(0,0,0,0.05);box-shadow:0 1px 2px rgba(0,0,0,0.05)}.pagination ul>li{display:inline}.pagination ul>li>a,.pagination ul>li>span{float:left;padding:4px 12px;line-height:20px;text-decoration:none;background-color:#fff;border:1px solid #ddd;border-left-width:0}.pagination ul>li>a:hover,.pagination ul>.active>a,.pagination ul>.active>span{background-color:#f5f5f5}.pagination ul>.active>a,.pagination ul>.active>span{color:#999;cursor:default}.pagination ul>.disabled>span,.pagination ul>.disabled>a,.pagination ul>.disabled>a:hover{color:#999;cursor:default;background-color:transparent}.pagination ul>li:first-child>a,.pagination ul>li:first-child>span{border-left-width:1px;-webkit-border-bottom-left-radius:4px;border-bottom-left-radius:4px;-webkit-border-top-left-radius:4px;border-top-left-radius:4px;-moz-border-radius-bottomleft:4px;-moz-border-radius-topleft:4px}.pagination ul>li:last-child>a,.pagination ul>li:last-child>span{-webkit-border-top-right-radius:4px;border-top-right-radius:4px;-webkit-border-bottom-right-radius:4px;border-bottom-right-radius:4px;-moz-border-radius-topright:4px;-moz-border-radius-bottomright:4px}.pagination-centered{text-align:center}.pagination-right{text-align:right}.pagination-large ul>li>a,.pagination-large ul>li>span{padding:11px 19px;font-size:17.5px}.pagination-large ul>li:first-child>a,.pagination-large ul>li:first-child>span{-webkit-border-bottom-left-radius:6px;border-bottom-left-radius:6px;-webkit-border-top-left-radius:6px;border-top-left-radius:6px;-moz-border-radius-bottomleft:6px;-moz-border-radius-topleft:6px}.pagination-large ul>li:last-child>a,.pagination-large ul>li:last-child>span{-webkit-border-top-right-radius:6px;border-top-right-radius:6px;-webkit-border-bottom-right-radius:6px;border-bottom-right-radius:6px;-moz-border-radius-topright:6px;-moz-border-radius-bottomright:6px}.pagination-mini ul>li:first-child>a,.pagination-small ul>li:first-child>a,.pagination-mini ul>li:first-child>span,.pagination-small ul>li:first-child>span{-webkit-border-bottom-left-radius:3px;border-bottom-left-radius:3px;-webkit-border-top-left-radius:3px;border-top-left-radius:3px;-moz-border-radius-bottomleft:3px;-moz-border-radius-topleft:3px}.pagination-mini ul>li:last-child>a,.pagination-small ul>li:last-child>a,.pagination-mini ul>li:last-child>span,.pagination-small ul>li:last-child>span{-webkit-border-top-right-radius:3px;border-top-right-radius:3px;-webkit-border-bottom-right-radius:3px;border-bottom-right-radius:3px;-moz-border-radius-topright:3px;-moz-border-radius-bottomright:3px}.pagination-small ul>li>a,.pagination-small ul>li>span{padding:2px 10px;font-size:11.9px}.pagination-mini ul>li>a,.pagination-mini ul>li>span{padding:0 6px;font-size:10.5px}.pager{margin:20px 0;text-align:center;list-style:none;*zoom:1}.pager:before,.pager:after{display:table;line-height:0;content:""}.pager:after{clear:both}.pager li{display:inline}.pager li>a,.pager li>span{display:inline-block;padding:5px 14px;background-color:#fff;border:1px solid #ddd;-webkit-border-radius:15px;-moz-border-radius:15px;border-radius:15px}.pager li>a:hover{text-decoration:none;background-color:#f5f5f5}.pager .next>a,.pager .next>span{float:right}.pager .previous>a,.pager .previous>span{float:left}.pager .disabled>a,.pager .disabled>a:hover,.pager .disabled>span{color:#999;cursor:default;background-color:#fff}.modal-backdrop{position:fixed;top:0;right:0;bottom:0;left:0;z-index:1040;background-color:#000}.modal-backdrop.fade{opacity:0}.modal-backdrop,.modal-backdrop.fade.in{opacity:.8;filter:alpha(opacity=80)}.modal{position:fixed;top:10%;left:50%;z-index:1050;width:560px;margin-left:-280px;background-color:#fff;border:1px solid #999;border:1px solid rgba(0,0,0,0.3);*border:1px solid #999;-webkit-border-radius:6px;-moz-border-radius:6px;border-radius:6px;outline:0;-webkit-box-shadow:0 3px 7px rgba(0,0,0,0.3);-moz-box-shadow:0 3px 7px rgba(0,0,0,0.3);box-shadow:0 3px 7px rgba(0,0,0,0.3);-webkit-background-clip:padding-box;-moz-background-clip:padding-box;background-clip:padding-box}.modal.fade{top:-25%;-webkit-transition:opacity .3s linear,top .3s ease-out;-moz-transition:opacity .3s linear,top .3s ease-out;-o-transition:opacity .3s linear,top .3s ease-out;transition:opacity .3s linear,top .3s ease-out}.modal.fade.in{top:10%}.modal-header{padding:9px 15px;border-bottom:1px solid #eee}.modal-header .close{margin-top:2px}.modal-header h3{margin:0;line-height:30px}.modal-body{position:relative;max-height:400px;padding:15px;overflow-y:auto}.modal-form{margin-bottom:0}.modal-footer{padding:14px 15px 15px;margin-bottom:0;text-align:right;background-color:#f5f5f5;border-top:1px solid #ddd;-webkit-border-radius:0 0 6px 6px;-moz-border-radius:0 0 6px 6px;border-radius:0 0 6px 6px;*zoom:1;-webkit-box-shadow:inset 0 1px 0 #fff;-moz-box-shadow:inset 0 1px 0 #fff;box-shadow:inset 0 1px 0 #fff}.modal-footer:before,.modal-footer:after{display:table;line-height:0;content:""}.modal-footer:after{clear:both}.modal-footer .btn+.btn{margin-bottom:0;margin-left:5px}.modal-footer .btn-group .btn+.btn{margin-left:-1px}.modal-footer .btn-block+.btn-block{margin-left:0}.tooltip{position:absolute;z-index:1030;display:block;padding:5px;font-size:11px;opacity:0;filter:alpha(opacity=0);visibility:visible}.tooltip.in{opacity:.8;filter:alpha(opacity=80)}.tooltip.top{margin-top:-3px}.tooltip.right{margin-left:3px}.tooltip.bottom{margin-top:3px}.tooltip.left{margin-left:-3px}.tooltip-inner{max-width:200px;padding:3px 8px;color:#fff;text-align:center;text-decoration:none;background-color:#000;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px}.tooltip-arrow{position:absolute;width:0;height:0;border-color:transparent;border-style:solid}.tooltip.top .tooltip-arrow{bottom:0;left:50%;margin-left:-5px;border-top-color:#000;border-width:5px 5px 0}.tooltip.right .tooltip-arrow{top:50%;left:0;margin-top:-5px;border-right-color:#000;border-width:5px 5px 5px 0}.tooltip.left .tooltip-arrow{top:50%;right:0;margin-top:-5px;border-left-color:#000;border-width:5px 0 5px 5px}.tooltip.bottom .tooltip-arrow{top:0;left:50%;margin-left:-5px;border-bottom-color:#000;border-width:0 5px 5px}.popover{position:absolute;top:0;left:0;z-index:1010;display:none;width:236px;padding:1px;text-align:left;white-space:normal;background-color:#fff;border:1px solid #ccc;border:1px solid rgba(0,0,0,0.2);-webkit-border-radius:6px;-moz-border-radius:6px;border-radius:6px;-webkit-box-shadow:0 5px 10px rgba(0,0,0,0.2);-moz-box-shadow:0 5px 10px rgba(0,0,0,0.2);box-shadow:0 5px 10px rgba(0,0,0,0.2);-webkit-background-clip:padding-box;-moz-background-clip:padding;background-clip:padding-box}.popover.top{margin-top:-10px}.popover.right{margin-left:10px}.popover.bottom{margin-top:10px}.popover.left{margin-left:-10px}.popover-title{padding:8px 14px;margin:0;font-size:14px;font-weight:normal;line-height:18px;background-color:#f7f7f7;border-bottom:1px solid #ebebeb;-webkit-border-radius:5px 5px 0 0;-moz-border-radius:5px 5px 0 0;border-radius:5px 5px 0 0}.popover-content{padding:9px 14px}.popover .arrow,.popover .arrow:after{position:absolute;display:block;width:0;height:0;border-color:transparent;border-style:solid}.popover .arrow{border-width:11px}.popover .arrow:after{border-width:10px;content:""}.popover.top .arrow{bottom:-11px;left:50%;margin-left:-11px;border-top-color:#999;border-top-color:rgba(0,0,0,0.25);border-bottom-width:0}.popover.top .arrow:after{bottom:1px;margin-left:-10px;border-top-color:#fff;border-bottom-width:0}.popover.right .arrow{top:50%;left:-11px;margin-top:-11px;border-right-color:#999;border-right-color:rgba(0,0,0,0.25);border-left-width:0}.popover.right .arrow:after{bottom:-10px;left:1px;border-right-color:#fff;border-left-width:0}.popover.bottom .arrow{top:-11px;left:50%;margin-left:-11px;border-bottom-color:#999;border-bottom-color:rgba(0,0,0,0.25);border-top-width:0}.popover.bottom .arrow:after{top:1px;margin-left:-10px;border-bottom-color:#fff;border-top-width:0}.popover.left .arrow{top:50%;right:-11px;margin-top:-11px;border-left-color:#999;border-left-color:rgba(0,0,0,0.25);border-right-width:0}.popover.left .arrow:after{right:1px;bottom:-10px;border-left-color:#fff;border-right-width:0}.thumbnails{margin-left:-20px;list-style:none;*zoom:1}.thumbnails:before,.thumbnails:after{display:table;line-height:0;content:""}.thumbnails:after{clear:both}.row-fluid .thumbnails{margin-left:0}.thumbnails>li{float:left;margin-bottom:20px;margin-left:20px}.thumbnail{display:block;padding:4px;line-height:20px;border:1px solid #ddd;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px;-webkit-box-shadow:0 1px 3px rgba(0,0,0,0.055);-moz-box-shadow:0 1px 3px rgba(0,0,0,0.055);box-shadow:0 1px 3px rgba(0,0,0,0.055);-webkit-transition:all .2s ease-in-out;-moz-transition:all .2s ease-in-out;-o-transition:all .2s ease-in-out;transition:all .2s ease-in-out}a.thumbnail:hover{border-color:#08c;-webkit-box-shadow:0 1px 4px rgba(0,105,214,0.25);-moz-box-shadow:0 1px 4px rgba(0,105,214,0.25);box-shadow:0 1px 4px rgba(0,105,214,0.25)}.thumbnail>img{display:block;max-width:100%;margin-right:auto;margin-left:auto}.thumbnail .caption{padding:9px;color:#555}.media,.media-body{overflow:hidden;*overflow:visible;zoom:1}.media,.media .media{margin-top:15px}.media:first-child{margin-top:0}.media-object{display:block}.media-heading{margin:0 0 5px}.media .pull-left{margin-right:10px}.media .pull-right{margin-left:10px}.media-list{margin-left:0;list-style:none}.label,.badge{display:inline-block;padding:2px 4px;font-size:11.844px;font-weight:bold;line-height:14px;color:#fff;text-shadow:0 -1px 0 rgba(0,0,0,0.25);white-space:nowrap;vertical-align:baseline;background-color:#999}.label{-webkit-border-radius:3px;-moz-border-radius:3px;border-radius:3px}.badge{padding-right:9px;padding-left:9px;-webkit-border-radius:9px;-moz-border-radius:9px;border-radius:9px}.label:empty,.badge:empty{display:none}a.label:hover,a.badge:hover{color:#fff;text-decoration:none;cursor:pointer}.label-important,.badge-important{background-color:#b94a48}.label-important[href],.badge-important[href]{background-color:#953b39}.label-warning,.badge-warning{background-color:#f89406}.label-warning[href],.badge-warning[href]{background-color:#c67605}.label-success,.badge-success{background-color:#468847}.label-success[href],.badge-success[href]{background-color:#356635}.label-info,.badge-info{background-color:#3a87ad}.label-info[href],.badge-info[href]{background-color:#2d6987}.label-inverse,.badge-inverse{background-color:#333}.label-inverse[href],.badge-inverse[href]{background-color:#1a1a1a}.btn .label,.btn .badge{position:relative;top:-1px}.btn-mini .label,.btn-mini .badge{top:0}@-webkit-keyframes progress-bar-stripes{from{background-position:40px 0}to{background-position:0 0}}@-moz-keyframes progress-bar-stripes{from{background-position:40px 0}to{background-position:0 0}}@-ms-keyframes progress-bar-stripes{from{background-position:40px 0}to{background-position:0 0}}@-o-keyframes progress-bar-stripes{from{background-position:0 0}to{background-position:40px 0}}@keyframes progress-bar-stripes{from{background-position:40px 0}to{background-position:0 0}}.progress{height:20px;margin-bottom:20px;overflow:hidden;background-color:#f7f7f7;background-image:-moz-linear-gradient(top,#f5f5f5,#f9f9f9);background-image:-webkit-gradient(linear,0 0,0 100%,from(#f5f5f5),to(#f9f9f9));background-image:-webkit-linear-gradient(top,#f5f5f5,#f9f9f9);background-image:-o-linear-gradient(top,#f5f5f5,#f9f9f9);background-image:linear-gradient(to bottom,#f5f5f5,#f9f9f9);background-repeat:repeat-x;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#fff5f5f5'',endColorstr=''#fff9f9f9'',GradientType=0);-webkit-box-shadow:inset 0 1px 2px rgba(0,0,0,0.1);-moz-box-shadow:inset 0 1px 2px rgba(0,0,0,0.1);box-shadow:inset 0 1px 2px rgba(0,0,0,0.1)}.progress .bar{float:left;width:0;height:100%;font-size:12px;color:#fff;text-align:center;text-shadow:0 -1px 0 rgba(0,0,0,0.25);background-color:#0e90d2;background-image:-moz-linear-gradient(top,#149bdf,#0480be);background-image:-webkit-gradient(linear,0 0,0 100%,from(#149bdf),to(#0480be));background-image:-webkit-linear-gradient(top,#149bdf,#0480be);background-image:-o-linear-gradient(top,#149bdf,#0480be);background-image:linear-gradient(to bottom,#149bdf,#0480be);background-repeat:repeat-x;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff149bdf'',endColorstr=''#ff0480be'',GradientType=0);-webkit-box-shadow:inset 0 -1px 0 rgba(0,0,0,0.15);-moz-box-shadow:inset 0 -1px 0 rgba(0,0,0,0.15);box-shadow:inset 0 -1px 0 rgba(0,0,0,0.15);-webkit-box-sizing:border-box;-moz-box-sizing:border-box;box-sizing:border-box;-webkit-transition:width .6s ease;-moz-transition:width .6s ease;-o-transition:width .6s ease;transition:width .6s ease}.progress .bar+.bar{-webkit-box-shadow:inset 1px 0 0 rgba(0,0,0,0.15),inset 0 -1px 0 rgba(0,0,0,0.15);-moz-box-shadow:inset 1px 0 0 rgba(0,0,0,0.15),inset 0 -1px 0 rgba(0,0,0,0.15);box-shadow:inset 1px 0 0 rgba(0,0,0,0.15),inset 0 -1px 0 rgba(0,0,0,0.15)}.progress-striped .bar{background-color:#149bdf;background-image:-webkit-gradient(linear,0 100%,100% 0,color-stop(0.25,rgba(255,255,255,0.15)),color-stop(0.25,transparent),color-stop(0.5,transparent),color-stop(0.5,rgba(255,255,255,0.15)),color-stop(0.75,rgba(255,255,255,0.15)),color-stop(0.75,transparent),to(transparent));background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-moz-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);-webkit-background-size:40px 40px;-moz-background-size:40px 40px;-o-background-size:40px 40px;background-size:40px 40px}.progress.active .bar{-webkit-animation:progress-bar-stripes 2s linear infinite;-moz-animation:progress-bar-stripes 2s linear infinite;-ms-animation:progress-bar-stripes 2s linear infinite;-o-animation:progress-bar-stripes 2s linear infinite;animation:progress-bar-stripes 2s linear infinite}.progress-danger .bar,.progress .bar-danger{background-color:#dd514c;background-image:-moz-linear-gradient(top,#ee5f5b,#c43c35);background-image:-webkit-gradient(linear,0 0,0 100%,from(#ee5f5b),to(#c43c35));background-image:-webkit-linear-gradient(top,#ee5f5b,#c43c35);background-image:-o-linear-gradient(top,#ee5f5b,#c43c35);background-image:linear-gradient(to bottom,#ee5f5b,#c43c35);background-repeat:repeat-x;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ffee5f5b'',endColorstr=''#ffc43c35'',GradientType=0)}.progress-danger.progress-striped .bar,.progress-striped .bar-danger{background-color:#ee5f5b;background-image:-webkit-gradient(linear,0 100%,100% 0,color-stop(0.25,rgba(255,255,255,0.15)),color-stop(0.25,transparent),color-stop(0.5,transparent),color-stop(0.5,rgba(255,255,255,0.15)),color-stop(0.75,rgba(255,255,255,0.15)),color-stop(0.75,transparent),to(transparent));background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-moz-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent)}.progress-success .bar,.progress .bar-success{background-color:#5eb95e;background-image:-moz-linear-gradient(top,#62c462,#57a957);background-image:-webkit-gradient(linear,0 0,0 100%,from(#62c462),to(#57a957));background-image:-webkit-linear-gradient(top,#62c462,#57a957);background-image:-o-linear-gradient(top,#62c462,#57a957);background-image:linear-gradient(to bottom,#62c462,#57a957);background-repeat:repeat-x;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff62c462'',endColorstr=''#ff57a957'',GradientType=0)}.progress-success.progress-striped .bar,.progress-striped .bar-success{background-color:#62c462;background-image:-webkit-gradient(linear,0 100%,100% 0,color-stop(0.25,rgba(255,255,255,0.15)),color-stop(0.25,transparent),color-stop(0.5,transparent),color-stop(0.5,rgba(255,255,255,0.15)),color-stop(0.75,rgba(255,255,255,0.15)),color-stop(0.75,transparent),to(transparent));background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-moz-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent)}.progress-info .bar,.progress .bar-info{background-color:#4bb1cf;background-image:-moz-linear-gradient(top,#5bc0de,#339bb9);background-image:-webkit-gradient(linear,0 0,0 100%,from(#5bc0de),to(#339bb9));background-image:-webkit-linear-gradient(top,#5bc0de,#339bb9);background-image:-o-linear-gradient(top,#5bc0de,#339bb9);background-image:linear-gradient(to bottom,#5bc0de,#339bb9);background-repeat:repeat-x;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#ff5bc0de'',endColorstr=''#ff339bb9'',GradientType=0)}.progress-info.progress-striped .bar,.progress-striped .bar-info{background-color:#5bc0de;background-image:-webkit-gradient(linear,0 100%,100% 0,color-stop(0.25,rgba(255,255,255,0.15)),color-stop(0.25,transparent),color-stop(0.5,transparent),color-stop(0.5,rgba(255,255,255,0.15)),color-stop(0.75,rgba(255,255,255,0.15)),color-stop(0.75,transparent),to(transparent));background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-moz-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent)}.progress-warning .bar,.progress .bar-warning{background-color:#faa732;background-image:-moz-linear-gradient(top,#fbb450,#f89406);background-image:-webkit-gradient(linear,0 0,0 100%,from(#fbb450),to(#f89406));background-image:-webkit-linear-gradient(top,#fbb450,#f89406);background-image:-o-linear-gradient(top,#fbb450,#f89406);background-image:linear-gradient(to bottom,#fbb450,#f89406);background-repeat:repeat-x;filter:progid:DXImageTransform.Microsoft.gradient(startColorstr=''#fffbb450'',endColorstr=''#fff89406'',GradientType=0)}.progress-warning.progress-striped .bar,.progress-striped .bar-warning{background-color:#fbb450;background-image:-webkit-gradient(linear,0 100%,100% 0,color-stop(0.25,rgba(255,255,255,0.15)),color-stop(0.25,transparent),color-stop(0.5,transparent),color-stop(0.5,rgba(255,255,255,0.15)),color-stop(0.75,rgba(255,255,255,0.15)),color-stop(0.75,transparent),to(transparent));background-image:-webkit-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-moz-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:-o-linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent);background-image:linear-gradient(45deg,rgba(255,255,255,0.15) 25%,transparent 25%,transparent 50%,rgba(255,255,255,0.15) 50%,rgba(255,255,255,0.15) 75%,transparent 75%,transparent)}.accordion{margin-bottom:20px}.accordion-group{margin-bottom:2px;border:1px solid #e5e5e5;-webkit-border-radius:4px;-moz-border-radius:4px;border-radius:4px}.accordion-heading{border-bottom:0}.accordion-heading .accordion-toggle{display:block;padding:8px 15px}.accordion-toggle{cursor:pointer}.accordion-inner{padding:9px 15px;border-top:1px solid #e5e5e5}.carousel{position:relative;margin-bottom:20px;line-height:1}.carousel-inner{position:relative;width:100%;overflow:hidden}.carousel-inner>.item{position:relative;display:none;-webkit-transition:.6s ease-in-out left;-moz-transition:.6s ease-in-out left;-o-transition:.6s ease-in-out left;transition:.6s ease-in-out left}.carousel-inner>.item>img{display:block;line-height:1}.carousel-inner>.active,.carousel-inner>.next,.carousel-inner>.prev{display:block}.carousel-inner>.active{left:0}.carousel-inner>.next,.carousel-inner>.prev{position:absolute;top:0;width:100%}.carousel-inner>.next{left:100%}.carousel-inner>.prev{left:-100%}.carousel-inner>.next.left,.carousel-inner>.prev.right{left:0}.carousel-inner>.active.left{left:-100%}.carousel-inner>.active.right{left:100%}.carousel-control{position:absolute;top:40%;left:15px;width:40px;height:40px;margin-top:-20px;font-size:60px;font-weight:100;line-height:30px;color:#fff;text-align:center;background:#222;border:3px solid #fff;-webkit-border-radius:23px;-moz-border-radius:23px;border-radius:23px;opacity:.5;filter:alpha(opacity=50)}.carousel-control.right{right:15px;left:auto}.carousel-control:hover{color:#fff;text-decoration:none;opacity:.9;filter:alpha(opacity=90)}.carousel-caption{position:absolute;right:0;bottom:0;left:0;padding:15px;background:#333;background:rgba(0,0,0,0.75)}.carousel-caption h4,.carousel-caption p{line-height:20px;color:#fff}.carousel-caption h4{margin:0 0 5px}.carousel-caption p{margin-bottom:0}.hero-unit{padding:60px;margin-bottom:30px;font-size:18px;font-weight:200;line-height:30px;color:inherit;background-color:#eee;-webkit-border-radius:6px;-moz-border-radius:6px;border-radius:6px}.hero-unit h1{margin-bottom:0;font-size:60px;line-height:1;letter-spacing:-1px;color:inherit}.hero-unit li{line-height:30px}.pull-right{float:right}.pull-left{float:left}.hide{display:none}.show{display:block}.invisible{visibility:hidden}.affix{position:fixed}
'
]

{ #category : #'request handling' }
OHFileRequestHandler >> handleRequest: aRequest [
	"quick hack, group and use a dictionary later"
	
	(#('files//' 'files') includes: aRequest uri path)   ifTrue: [^ZnResponse unauthorized: 'No permisson'].
	(aRequest uri path = 'files/css/bootstrap.min.css') ifTrue: [^self cssResponseFor: #cssbootstrapminCssContent ].
	(aRequest uri path = 'files/js/bootstrap.min.js') ifTrue: [^self javaScriptResponseFor: #jsbootstrapminJs ].
	(aRequest uri path = 'files/js/jquery-1.8.1.min.js') ifTrue: [^self javaScriptResponseFor: #jquery181minJs ].
	(aRequest uri path = 'files/js/MarkdownConverter.js' ) ifTrue: [^self javaScriptResponseFor: #MarkdownConverterJs ].
	(aRequest uri path = 'files/img/glyphicons-halflings.png') ifTrue: [^self imagePNGResponseFor: #imgglyphiconshalflingsPngContent ].	
	(aRequest uri path = 'files/img/glyphicons-halflings-white.png') ifTrue: [^self imagePNGResponseFor: #imgglyphiconshalflingswhitePngContent ].
	(aRequest uri path = 'files/img/pharo.png') ifTrue: [^self imagePNGResponseFor: #pharoPngContent ].
	^ZnResponse notFound: aRequest uri
]

{ #category : #private }
OHFileRequestHandler >> imagePNGResponseFor: aContentSelector [

	^self respondWith: (self perform: aContentSelector) usingMIMEType: 'image/png'
	
]

{ #category : #uploads }
OHFileRequestHandler >> imgglyphiconshalflingsPngContent [
	^ #(137 80 78 71 13 10 26 10 0 0 0 13 73 72 68 82 0 0 1 213 0 0 0 159 8 4 0 0 0 5 4 139 194 0 0 0 25 116 69 88 116 83 111 102 116 119 97 114 101 0 65 100 111 98 101 32 73 109 97 103 101 82 101 97 100 121 113 201 101 60 0 0 49 161 73 68 65 84 120 218 237 125 109 108 92 69 186 166 87 178 180 94 201 186 182 68 36 124 110 28 119 39 254 160 59 118 127 209 142 199 56 141 109 48 249 152 107 60 102 217 56 217 128 179 14 19 60 203 104 51 36 136 12 32 18 8 12 98 44 109 110 228 160 204 13 163 32 210 147 17 23 184 215 18 190 171 48 241 222 31 76 32 89 96 54 115 39 29 62 6 20 172 81 2 1 188 191 174 29 183 238 159 253 83 251 190 167 186 250 156 110 159 83 245 86 167 59 49 75 189 71 137 219 246 115 234 212 169 243 62 85 111 189 199 245 84 85 149 49 99 198 150 157 89 117 214 188 197 236 99 222 249 97 38 247 163 194 35 67 44 112 216 154 196 18 20 184 62 107 218 186 12 23 159 182 250 150 85 131 76 87 10 15 45 115 198 110 199 51 86 157 113 188 235 126 78 154 254 163 239 111 214 24 252 99 232 199 248 73 187 126 76 197 0 27 21 163 123 255 224 45 9 198 250 241 72 56 37 95 232 239 157 77 178 194 163 119 246 66 191 226 178 54 69 87 178 213 44 196 162 112 134 188 25 130 172 157 197 89 2 254 15 50 43 173 40 89 179 235 176 2 240 64 160 239 177 38 225 243 65 187 47 154 182 2 164 6 142 181 51 107 88 227 129 104 224 27 223 141 216 45 25 97 141 239 170 31 179 215 65 192 7 212 232 60 62 80 248 149 140 39 92 193 163 155 74 203 59 40 248 125 134 35 0 155 81 122 132 150 255 148 128 135 58 52 195 253 37 109 63 110 102 162 110 116 75 42 24 192 175 178 230 108 203 57 74 201 216 218 43 161 68 222 238 73 167 253 89 117 49 89 145 168 172 90 94 156 160 40 30 93 89 89 69 173 190 102 64 236 157 192 30 226 208 158 174 108 88 225 238 122 93 135 85 215 116 165 29 16 9 168 143 117 185 13 190 38 225 1 53 45 80 154 164 237 87 128 125 131 254 64 116 240 145 124 221 35 76 245 152 89 127 146 61 251 180 115 240 159 200 220 130 31 172 198 249 44 119 35 7 43 190 82 241 148 43 20 63 145 198 139 97 214 120 209 255 9 88 233 48 248 14 34 16 27 101 97 41 157 116 253 71 23 15 221 42 212 161 119 86 16 174 119 22 235 86 94 170 194 0 114 102 37 120 66 4 40 8 113 214 188 188 52 62 154 22 31 252 87 213 71 182 35 221 4 241 142 108 87 17 85 60 208 129 204 248 209 19 187 88 74 86 209 182 183 147 108 247 139 172 193 190 82 253 196 238 36 107 253 68 86 114 211 73 175 174 163 233 164 55 58 240 88 60 143 115 62 37 88 224 49 2 157 190 78 178 142 69 122 15 26 249 186 119 150 138 167 59 121 210 238 57 239 122 192 57 248 79 212 37 23 126 150 227 151 126 165 225 117 169 202 201 151 4 42 250 61 177 170 170 196 231 73 27 209 120 145 99 225 121 125 174 246 31 28 89 40 254 163 235 111 214 24 18 149 117 10 194 177 78 36 171 94 24 172 106 159 254 11 238 174 187 255 2 101 92 245 137 105 88 237 241 157 156 172 93 217 227 59 89 45 165 114 135 246 0 215 227 172 17 209 178 138 38 190 129 62 186 33 127 165 122 108 8 89 201 97 86 72 86 78 212 176 207 57 61 135 139 93 138 31 61 135 253 31 141 152 176 199 109 82 175 204 77 222 253 30 142 27 127 100 187 26 175 79 85 28 67 11 169 74 27 85 105 84 21 125 114 241 87 26 190 168 87 39 18 21 159 218 185 117 170 184 41 202 162 132 233 22 247 31 203 70 34 89 85 254 35 240 252 80 227 215 190 159 132 231 234 38 220 145 237 208 133 207 232 204 82 229 79 192 170 139 216 119 121 122 219 233 109 3 25 36 171 170 187 79 178 209 223 20 254 115 63 32 32 43 94 144 70 84 219 193 234 221 223 73 144 69 225 113 247 37 185 243 38 153 155 172 130 168 126 231 12 62 238 77 213 193 199 125 93 177 225 212 150 226 16 187 119 22 238 187 65 134 239 153 27 63 10 14 91 203 250 247 78 116 101 101 120 110 238 40 229 230 142 170 149 159 171 66 186 100 26 157 207 77 84 217 20 170 112 202 165 154 110 113 255 113 238 83 233 63 154 248 216 98 87 150 251 188 232 144 88 109 87 54 241 141 206 120 42 123 2 86 95 227 187 248 251 169 33 86 195 106 206 167 240 115 227 187 86 76 94 106 239 145 194 127 133 13 88 107 207 81 106 169 85 244 255 174 208 54 156 5 215 235 115 30 107 148 245 204 169 110 126 253 91 252 113 242 199 184 254 45 255 166 96 13 216 79 21 31 3 25 25 145 160 201 58 71 166 28 244 200 20 235 148 221 55 226 135 223 108 181 131 34 107 184 153 253 199 127 144 227 237 115 82 249 25 101 138 50 170 174 118 29 242 81 213 61 206 81 198 188 74 207 85 173 88 96 161 29 103 158 1 26 81 121 126 19 9 196 143 238 75 131 183 200 176 220 127 176 69 176 93 212 254 35 240 252 80 227 187 231 58 151 116 166 157 217 100 182 92 84 189 47 117 199 31 241 247 155 218 248 157 227 231 59 254 216 179 249 58 168 74 203 99 45 37 39 166 160 101 231 141 255 12 28 113 129 147 213 10 4 63 2 106 188 34 47 121 104 134 133 172 52 142 172 56 162 90 105 22 26 154 241 191 194 249 212 210 49 242 124 74 85 255 167 239 117 240 15 62 162 190 95 196 255 205 78 235 204 221 59 104 120 119 191 78 25 85 11 211 74 178 81 85 55 3 92 233 185 106 243 169 132 29 204 174 98 84 162 58 163 175 152 179 202 2 66 225 63 54 241 8 254 163 235 111 189 127 74 176 194 49 206 138 37 136 243 73 10 85 89 45 31 73 131 239 217 105 52 123 132 61 159 114 199 164 55 136 170 64 41 72 136 75 231 74 43 134 102 18 152 52 207 88 25 254 56 67 215 100 195 63 39 106 216 14 131 49 244 197 252 32 146 149 22 78 209 242 215 60 155 11 51 218 57 252 159 146 213 69 60 140 119 223 172 134 128 86 141 135 247 122 151 69 125 224 253 94 95 101 230 170 180 12 112 165 231 170 31 116 235 182 190 51 250 138 57 171 44 227 170 235 63 186 248 177 103 146 108 205 89 247 79 214 192 184 60 246 140 206 120 170 120 2 213 124 134 186 146 97 22 216 142 249 170 85 101 151 133 170 240 70 245 178 211 235 135 9 243 49 22 218 59 129 147 123 12 69 70 211 48 15 96 129 5 255 198 227 68 197 82 145 166 252 43 146 85 214 20 14 89 105 68 229 217 223 209 52 235 30 63 138 89 96 29 124 66 129 135 190 115 50 200 220 121 105 112 155 73 255 113 227 187 62 87 213 111 253 13 167 4 86 156 185 225 84 249 252 71 219 223 26 122 103 35 248 10 37 150 139 17 207 68 48 35 220 160 51 158 170 152 19 91 116 166 105 3 153 216 162 186 27 40 11 85 215 44 196 93 206 49 50 53 144 217 124 238 248 78 197 204 173 1 102 119 216 55 119 179 32 230 154 237 198 11 248 191 117 43 14 190 194 138 23 217 194 93 168 68 181 98 93 223 194 75 166 32 156 217 120 98 87 234 11 213 155 55 29 124 227 149 208 146 250 135 88 227 149 155 149 1 174 252 123 85 221 214 199 24 137 99 249 153 24 71 149 207 127 244 241 88 135 8 107 194 172 254 124 19 139 40 255 0 104 41 73 85 204 97 41 22 255 108 112 32 51 144 249 108 16 250 238 212 117 80 85 252 93 68 146 240 151 41 169 47 16 55 126 52 87 137 22 184 116 7 53 25 229 188 24 74 125 177 251 86 191 7 233 249 10 88 245 48 171 167 134 122 230 32 203 86 77 169 195 198 59 62 190 71 212 153 213 94 232 127 160 175 124 248 184 103 70 58 206 228 163 106 97 90 233 187 246 94 21 41 55 52 67 35 106 238 25 119 114 44 208 181 83 245 108 245 252 71 31 143 117 216 59 49 144 233 204 118 207 109 62 7 127 60 209 41 191 15 125 170 242 171 60 189 235 240 86 90 11 117 101 219 160 68 231 159 43 106 213 121 135 150 235 175 26 171 74 54 86 123 106 11 253 177 146 75 173 129 62 180 134 90 3 247 213 225 81 213 150 15 239 253 183 38 254 109 90 58 158 150 1 190 49 239 85 161 77 66 229 126 162 229 242 31 10 30 198 97 24 237 192 131 58 228 47 225 156 151 58 75 255 87 158 87 79 29 210 160 38 133 173 159 170 186 89 6 180 170 174 50 102 236 6 249 143 241 55 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 177 229 103 165 200 42 26 51 102 236 70 19 53 221 76 16 98 180 145 165 8 78 142 193 50 35 84 102 61 67 233 16 96 33 25 150 127 16 14 252 90 71 175 85 101 234 163 135 135 101 130 197 50 86 195 21 169 207 60 156 49 109 107 83 164 201 229 3 30 197 52 105 207 151 42 46 154 123 78 252 56 88 153 97 4 106 126 6 142 233 239 218 128 226 110 65 154 120 44 255 151 215 37 102 69 58 195 124 233 89 152 68 86 247 106 11 10 158 235 172 194 162 218 108 103 54 194 40 58 171 107 126 140 165 247 77 246 77 226 215 53 63 166 52 9 93 87 79 183 62 186 248 232 175 139 87 165 200 23 163 151 90 31 148 21 105 71 252 124 152 81 203 71 252 74 22 101 180 231 75 91 89 99 213 181 185 112 109 106 69 92 102 47 190 199 142 56 38 188 79 81 255 51 205 32 25 139 226 156 246 253 46 51 25 116 185 234 116 50 39 189 45 86 224 56 223 249 225 133 112 131 88 181 83 176 114 199 89 35 74 33 171 251 241 81 240 184 234 127 32 131 34 164 44 117 98 215 64 70 173 179 26 250 20 75 223 58 190 117 220 94 237 249 105 121 169 170 91 31 93 60 46 67 119 175 139 0 157 131 175 43 87 31 92 141 41 191 239 98 188 170 157 10 107 175 114 45 161 23 4 229 131 238 46 77 162 6 116 164 23 218 128 212 77 168 145 113 198 202 132 21 245 143 192 178 254 211 219 176 30 167 183 141 166 35 36 157 94 88 36 158 209 34 156 141 167 137 189 187 241 86 96 149 84 138 52 153 27 25 109 225 210 126 247 119 37 80 181 112 49 183 154 124 133 43 38 85 120 212 89 5 137 138 56 171 197 42 194 114 178 56 58 163 236 230 172 0 23 244 224 107 55 81 208 131 210 128 84 170 186 235 3 226 147 202 250 184 240 147 214 36 1 31 136 219 2 208 142 245 206 198 153 191 10 129 83 62 126 167 83 31 252 174 245 181 132 106 204 115 225 173 58 53 222 113 46 119 176 38 95 90 46 4 244 88 61 149 170 137 252 58 222 136 98 119 6 235 96 148 193 26 210 32 95 224 8 107 100 130 123 39 162 202 48 219 58 216 100 199 14 220 115 212 254 35 240 171 24 113 171 141 28 190 105 33 50 50 52 211 246 149 252 110 113 137 92 146 57 132 45 145 170 75 85 23 84 228 115 83 85 189 236 27 117 86 15 111 21 149 64 59 188 85 174 179 122 219 62 94 250 161 61 188 151 78 178 219 246 149 143 170 238 250 112 188 188 62 2 111 245 133 80 193 191 79 133 199 218 23 10 144 160 64 73 251 19 234 250 64 224 27 163 215 39 71 147 144 106 53 169 27 111 175 42 85 174 62 21 238 228 94 171 42 145 101 155 119 139 18 228 62 205 171 202 167 135 215 225 171 160 18 81 176 134 148 53 12 205 132 175 202 231 134 60 36 231 35 158 53 182 74 210 217 187 241 168 106 210 246 54 101 238 41 240 219 95 13 253 238 249 251 100 93 177 211 50 130 176 150 66 58 192 135 170 94 242 40 42 178 58 56 74 202 193 209 89 21 213 83 233 172 134 174 242 210 239 75 221 151 147 232 12 93 85 52 95 198 114 106 164 8 123 220 245 225 53 146 215 135 227 97 199 145 47 237 121 243 151 86 157 2 255 63 147 236 71 191 116 255 228 71 191 4 17 172 15 212 245 137 98 64 120 80 85 159 228 55 2 79 51 167 124 170 233 141 170 9 15 255 73 176 242 81 53 206 30 221 81 252 179 71 119 196 9 42 25 40 59 179 119 162 25 102 183 48 42 215 80 240 85 85 143 60 16 89 164 198 148 136 255 241 182 118 134 178 188 254 98 161 206 116 194 246 53 123 50 33 235 44 125 169 138 189 236 210 166 150 143 148 58 41 7 183 206 106 50 79 107 153 206 170 21 19 146 39 16 12 214 138 48 73 46 113 92 40 196 37 111 106 81 31 203 22 166 226 196 150 213 135 227 97 60 234 182 235 212 141 139 148 101 120 220 65 103 116 139 251 39 163 91 100 59 215 184 219 7 30 249 171 170 250 96 114 200 99 100 187 236 27 158 166 150 106 8 160 138 80 185 70 85 221 36 148 23 85 101 74 189 73 54 217 84 252 179 201 38 90 125 170 170 238 122 20 191 222 245 40 149 122 247 12 118 102 117 168 122 207 32 191 155 123 6 125 219 191 223 157 209 229 221 158 108 120 147 206 85 245 26 90 23 239 232 172 138 199 46 215 89 229 178 159 98 204 206 231 21 127 37 187 134 142 16 151 168 15 110 119 192 183 64 144 215 199 169 191 184 83 57 222 214 124 197 186 115 37 218 62 203 22 95 245 111 35 167 252 158 57 216 92 164 69 85 126 255 5 47 221 218 129 247 116 18 40 114 157 91 189 81 181 20 170 90 117 3 153 3 251 79 111 59 176 159 203 232 29 219 33 77 114 85 187 93 219 206 48 84 211 234 99 5 112 68 197 145 213 63 0 46 172 245 218 99 27 206 234 80 117 237 177 205 231 172 24 70 128 178 128 153 251 178 59 15 156 188 30 170 138 76 95 185 169 170 171 179 138 249 83 222 211 98 125 184 82 47 140 74 95 203 231 14 43 25 223 212 104 165 50 36 23 245 97 181 163 105 144 11 173 85 213 199 169 191 184 83 57 62 191 141 208 132 125 55 19 170 54 114 202 7 169 181 122 117 249 222 237 249 224 126 229 155 189 52 173 253 111 196 168 10 49 74 156 173 128 20 209 10 181 140 94 177 204 152 227 192 126 163 24 30 163 105 30 0 67 222 184 129 53 192 255 53 20 60 80 239 218 190 157 114 239 47 196 71 190 30 255 89 235 107 224 171 181 148 151 53 162 109 75 10 128 139 19 50 229 167 170 158 206 170 53 44 194 223 222 63 241 49 39 31 2 15 211 106 195 147 81 148 250 192 112 23 84 235 190 186 240 246 198 10 42 188 243 126 209 73 63 72 213 215 157 242 171 41 58 180 250 186 181 92 169 249 249 251 232 248 74 143 170 58 51 231 209 180 23 85 71 21 111 41 88 240 196 46 204 195 139 188 177 234 42 2 127 106 139 92 247 190 24 63 125 223 227 137 142 197 71 126 65 123 89 35 198 87 17 18 47 51 170 234 233 172 182 191 33 202 188 227 143 248 61 223 239 67 246 103 4 197 117 9 42 212 254 245 117 95 245 240 222 174 43 171 81 101 235 131 53 194 119 175 58 248 202 207 85 233 134 234 203 75 169 138 63 85 156 87 139 27 49 106 92 199 198 83 53 47 29 60 171 1 122 55 80 94 214 240 247 170 60 19 44 83 164 20 191 21 106 136 85 85 56 252 220 16 170 234 232 172 118 44 138 50 135 95 198 239 135 95 22 223 251 105 218 235 187 138 174 238 171 30 94 159 170 165 214 7 19 82 3 25 53 30 94 118 164 246 78 108 62 71 215 185 93 250 103 133 254 245 119 246 188 115 14 249 110 11 122 84 117 79 61 138 63 47 15 147 211 219 253 122 198 178 99 62 218 254 6 206 159 24 98 182 35 55 214 187 99 103 146 230 107 191 254 222 155 84 157 85 151 2 106 144 247 169 42 45 84 61 21 93 221 250 232 227 117 117 125 175 163 62 221 168 218 78 208 173 13 217 248 14 29 157 91 13 93 226 148 7 58 37 47 95 155 12 174 235 83 247 122 93 54 68 46 212 109 174 135 131 172 196 236 68 55 85 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 5 230 250 163 236 180 62 222 74 19 52 104 235 80 80 133 174 43 171 167 65 155 59 39 157 71 95 174 88 75 161 218 109 76 171 133 152 53 73 46 125 44 119 70 70 117 167 222 109 36 83 150 45 165 69 141 45 59 195 149 10 67 51 73 45 21 96 7 207 66 235 223 82 157 213 120 49 190 136 210 147 84 177 74 221 149 59 104 206 138 156 56 163 11 68 234 89 248 170 74 141 130 27 23 111 59 180 231 192 254 222 217 16 89 194 154 53 140 31 77 178 205 231 228 75 183 172 201 176 77 127 157 181 59 154 170 190 37 80 186 148 142 0 100 57 75 238 104 148 248 128 110 231 180 68 24 91 122 175 197 103 86 104 232 44 174 127 18 165 39 67 3 25 186 10 112 33 94 77 214 40 179 87 75 50 170 88 165 62 85 81 130 196 37 226 246 176 94 131 16 155 112 56 9 203 189 214 94 35 144 206 150 216 132 21 20 43 46 64 151 212 241 103 234 67 234 122 37 201 148 26 4 45 80 114 11 10 150 130 184 75 191 88 255 136 10 188 133 130 166 110 211 193 22 183 62 189 187 215 61 139 213 148 222 209 168 240 197 101 83 22 118 82 151 215 21 163 146 76 151 122 170 242 189 214 53 37 57 85 81 83 32 162 161 2 92 140 87 145 213 171 217 202 75 213 246 39 220 104 153 112 41 23 195 180 10 74 183 148 114 152 104 161 223 13 158 238 157 77 48 202 70 12 162 206 40 102 29 95 164 82 53 241 7 47 201 47 47 167 2 71 239 228 43 24 243 170 139 245 254 163 177 14 182 120 9 28 49 34 232 191 254 179 168 101 83 240 250 11 53 133 144 10 173 214 58 84 245 246 102 127 190 240 61 43 138 55 20 201 81 21 201 167 167 2 92 140 151 147 181 178 84 69 162 161 160 167 115 252 224 188 172 239 114 198 223 222 89 174 115 56 250 27 149 28 38 134 107 237 236 249 251 182 255 173 170 35 112 83 213 138 53 157 4 77 224 179 84 170 98 171 170 68 220 138 91 78 103 161 53 81 210 92 115 199 26 237 0 53 80 66 64 91 241 0 56 201 168 145 86 49 170 20 170 162 164 175 172 38 246 166 52 87 115 121 30 91 154 199 190 10 159 119 210 85 128 189 241 50 178 86 150 170 182 238 236 55 5 193 194 55 148 128 106 239 196 212 208 212 208 222 137 100 94 126 89 102 183 237 67 169 171 95 130 192 104 59 97 46 204 199 234 38 134 77 174 10 105 157 32 30 167 22 20 194 85 150 170 186 26 22 186 1 170 87 112 122 115 3 96 62 247 47 214 34 164 212 39 79 242 73 157 246 225 218 219 178 231 139 28 27 121 5 137 138 155 128 4 22 172 58 27 207 66 122 100 245 195 251 147 181 242 84 141 23 244 159 113 194 163 239 157 61 208 185 138 173 98 7 58 133 130 176 34 252 189 186 249 109 171 47 190 1 209 45 47 80 220 29 247 87 193 68 81 243 199 180 205 144 226 255 53 201 238 254 31 55 159 170 186 26 22 250 170 23 250 1 109 229 2 96 244 23 72 253 165 29 37 65 157 218 243 86 181 210 33 201 72 188 212 155 215 191 165 18 23 181 247 64 8 34 81 163 182 0 122 227 197 28 222 139 124 235 223 146 84 214 7 191 254 45 239 179 42 79 85 253 94 186 251 210 166 54 252 186 169 173 251 18 33 200 238 139 67 119 132 2 107 209 124 104 162 38 5 72 100 53 142 76 69 89 224 121 18 145 142 39 217 198 163 55 159 170 37 189 42 211 60 67 39 64 173 108 0 140 132 27 153 98 33 119 0 76 187 87 87 26 40 4 37 248 210 219 67 16 223 230 143 52 20 175 131 23 131 129 230 251 163 185 51 92 187 250 20 147 15 132 179 164 251 208 120 225 173 244 250 183 188 207 42 141 170 189 179 167 183 81 70 188 210 168 26 133 60 241 233 109 167 183 133 31 142 18 186 131 208 223 131 28 103 63 223 137 204 30 195 251 168 164 184 31 18 94 177 15 41 68 138 125 134 123 223 85 142 170 214 152 29 124 141 81 8 173 155 207 213 61 67 39 64 173 124 0 140 25 117 119 0 76 187 215 130 81 176 69 175 61 145 63 254 120 43 214 120 165 13 34 190 219 254 151 103 253 221 228 83 17 213 11 239 79 212 210 168 106 235 228 215 136 13 46 212 193 102 113 106 91 253 232 155 89 224 163 192 71 205 164 253 67 195 236 225 231 132 147 109 62 7 123 232 252 61 41 173 20 176 198 90 175 37 217 157 191 167 80 9 187 140 7 250 42 71 213 230 220 93 235 7 192 149 200 0 47 151 0 184 56 3 76 23 1 212 205 0 119 129 186 36 63 56 127 252 241 77 185 41 92 196 175 171 17 228 163 16 181 24 47 35 170 55 85 135 102 100 55 39 54 180 16 27 92 16 104 49 239 10 118 2 73 146 24 102 148 69 73 114 152 152 199 61 144 127 189 49 248 119 246 220 92 242 87 75 214 30 158 86 90 5 196 72 16 19 75 252 156 103 254 90 137 131 205 161 157 36 6 109 164 228 120 183 139 201 210 32 37 5 156 203 13 127 221 25 96 106 125 212 84 117 84 28 129 129 246 81 74 90 175 232 42 72 62 42 81 221 120 107 76 70 84 191 16 192 31 239 222 121 134 147 85 213 20 197 127 2 161 45 134 41 145 195 180 14 98 190 174 105 65 168 217 243 124 113 96 193 191 70 173 5 27 39 193 159 31 212 43 9 152 225 231 52 94 81 182 121 11 180 120 139 206 72 41 146 30 238 35 196 116 94 173 149 63 64 93 94 25 96 65 213 82 234 83 138 170 113 25 168 106 103 158 66 58 197 114 60 104 204 134 202 25 82 21 110 17 133 2 213 202 122 212 22 148 223 80 206 166 203 41 17 167 242 91 21 43 149 110 11 234 210 77 217 88 1 254 72 33 135 166 180 185 127 48 230 141 231 73 15 247 129 137 148 114 6 156 203 13 175 239 115 75 207 161 213 167 20 85 227 82 50 240 203 84 9 88 253 103 0 198 180 218 179 69 253 19 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 110 142 193 106 185 192 178 168 199 180 121 22 198 140 73 136 218 120 81 252 113 186 20 55 102 77 131 238 203 52 69 22 204 70 159 177 46 195 250 151 51 52 60 46 231 6 105 148 225 146 59 155 225 101 208 146 105 154 178 178 49 99 37 57 249 186 230 238 75 9 233 202 17 238 134 205 160 50 20 129 127 205 74 141 67 148 236 110 198 213 119 217 4 252 15 248 12 69 194 164 249 99 144 70 249 138 130 180 134 161 19 96 142 224 53 118 54 171 37 203 191 93 248 51 184 170 84 171 252 121 236 196 96 141 126 157 154 168 97 162 178 178 91 91 22 219 74 31 171 62 75 15 15 247 219 183 108 60 50 239 45 52 191 89 138 231 75 226 104 103 81 176 174 246 76 211 196 120 156 86 167 119 222 80 182 236 126 209 201 3 31 77 13 245 206 166 190 144 143 145 184 48 108 32 51 154 198 133 214 97 197 138 73 84 136 25 200 128 104 119 74 172 19 109 188 168 172 232 193 168 173 153 20 120 73 77 164 213 185 165 184 124 157 171 85 55 120 203 134 83 189 179 126 50 157 2 223 149 29 63 138 107 7 87 49 107 15 165 252 189 19 67 51 93 217 227 59 89 173 149 110 83 222 1 151 186 210 145 65 23 237 31 101 186 88 202 89 122 248 56 44 39 130 120 137 60 13 18 107 55 75 21 120 145 157 131 222 194 93 214 249 36 179 165 120 190 36 142 118 22 5 235 180 103 152 84 35 119 251 147 59 111 240 31 201 253 242 194 64 11 8 200 122 161 95 86 208 218 247 109 225 110 124 162 29 72 214 181 239 203 104 29 229 216 90 103 45 94 84 65 110 171 175 45 135 12 41 131 224 150 175 64 30 52 157 91 42 212 57 120 75 227 197 198 139 231 214 193 178 178 106 5 62 197 26 33 44 7 1 172 86 116 203 58 101 249 176 212 15 151 194 113 18 110 56 37 111 104 20 178 202 233 83 132 40 50 232 92 81 135 203 94 233 97 105 103 233 225 241 26 237 184 70 151 184 51 128 179 118 179 84 85 68 25 86 184 108 146 81 200 234 133 167 172 87 165 99 221 237 25 37 146 85 224 229 170 101 142 113 169 52 159 210 157 194 186 47 237 190 85 190 16 13 165 36 134 95 230 159 81 21 33 194 228 180 62 188 181 248 17 201 213 116 215 124 233 32 215 44 200 155 2 71 60 22 116 223 67 247 165 193 91 212 120 84 88 109 102 124 236 3 183 60 169 196 79 218 161 175 77 84 217 2 124 40 119 58 204 220 227 95 88 218 21 8 164 211 254 106 55 119 176 180 179 116 241 188 229 19 32 187 10 65 88 223 205 166 170 112 217 36 137 26 94 120 90 171 82 177 238 246 164 145 213 193 235 106 172 120 148 238 20 230 214 96 240 51 20 61 17 226 94 177 15 241 28 127 108 108 177 43 203 151 101 187 31 81 226 27 217 56 28 103 56 86 11 135 145 43 254 57 77 203 239 1 235 47 163 170 192 7 158 143 0 150 111 232 49 52 115 110 157 98 20 155 12 161 30 235 116 88 217 220 141 23 219 115 138 253 201 252 215 118 69 192 108 43 64 92 140 146 101 184 28 44 229 44 183 99 209 174 226 60 167 40 134 194 105 245 72 86 89 170 114 151 165 81 195 11 79 21 55 163 97 221 237 73 169 145 62 81 37 100 213 35 106 85 213 134 179 124 59 12 72 175 216 91 98 200 194 193 238 185 206 172 199 35 202 202 198 225 161 25 28 171 243 2 44 87 233 115 55 78 84 25 49 4 126 221 212 233 109 16 38 199 187 178 123 39 32 92 173 150 227 159 190 183 11 146 98 237 66 75 74 18 190 111 56 229 37 183 33 15 152 133 128 36 149 170 81 151 155 168 207 106 58 169 135 47 166 82 88 41 36 83 121 170 22 222 179 127 12 228 141 167 235 16 82 176 133 68 85 103 95 68 251 131 232 187 166 198 74 207 92 209 253 234 18 181 170 106 223 78 174 168 214 150 83 85 59 126 183 63 182 247 79 137 188 104 152 115 115 253 23 100 225 245 198 163 125 147 14 54 206 40 84 13 60 22 205 213 95 158 52 201 239 220 18 98 53 248 245 212 22 214 32 163 94 78 11 170 246 248 78 140 37 56 81 101 106 70 188 55 116 111 231 164 238 77 121 219 211 169 234 96 41 103 157 91 167 135 47 166 210 208 204 199 247 220 124 170 186 239 193 63 6 242 198 211 169 74 193 230 229 117 220 71 167 186 253 227 76 239 229 157 149 142 23 222 47 127 61 163 67 84 220 160 104 100 202 105 102 72 186 212 248 99 199 158 129 249 230 217 226 71 52 246 140 44 188 238 248 243 225 245 142 178 96 146 68 213 158 195 123 39 120 253 163 202 71 95 112 47 53 248 226 137 64 109 32 43 215 36 106 86 212 72 168 188 138 51 213 97 15 34 133 144 42 197 169 28 44 229 44 161 251 72 191 74 210 181 175 15 200 184 133 84 94 81 121 170 162 111 38 73 195 137 23 158 74 85 26 86 119 87 31 167 253 195 76 231 101 77 184 248 126 3 143 241 215 51 116 162 162 189 147 16 143 28 178 187 65 169 227 54 244 206 218 193 114 204 221 119 201 164 202 54 156 141 178 213 191 237 191 32 208 242 157 92 48 72 192 76 37 76 170 26 88 53 234 146 99 168 161 198 231 147 64 160 72 72 195 131 4 90 139 186 124 78 86 220 203 43 55 87 77 171 195 30 123 252 173 166 168 30 23 99 105 103 233 226 133 224 42 188 206 234 164 200 184 85 154 170 220 55 105 195 137 23 158 26 171 208 177 122 138 136 250 100 245 32 42 204 12 63 21 175 103 116 228 199 88 245 145 237 56 238 245 204 157 79 169 176 88 205 8 238 176 58 239 244 93 50 252 201 141 93 217 112 94 176 184 43 43 242 199 62 193 248 19 184 65 148 232 219 86 218 155 69 237 123 226 230 225 11 147 2 180 68 66 46 200 38 168 30 47 197 210 206 210 195 227 53 54 159 131 169 65 227 114 120 89 35 220 149 22 247 121 225 41 244 163 99 75 81 20 116 200 170 243 178 166 224 126 173 0 206 240 182 255 173 234 245 140 199 197 33 32 236 153 59 182 67 125 30 202 131 238 157 24 200 116 102 123 230 54 159 131 36 78 167 252 28 86 115 106 11 254 185 1 119 117 112 152 90 41 122 197 129 253 124 250 45 148 119 15 236 103 43 110 30 222 77 86 106 198 47 31 100 43 85 143 189 176 148 179 4 202 126 205 175 196 219 234 197 29 178 105 141 151 243 58 95 105 120 154 163 11 119 181 234 104 113 159 131 114 62 169 233 167 131 45 205 120 171 235 188 172 41 186 223 221 183 218 121 208 198 82 4 61 33 32 236 150 211 200 29 6 195 172 58 5 248 14 138 74 47 108 204 20 202 73 107 135 212 14 195 86 64 185 110 229 221 21 55 23 239 52 55 53 227 231 56 171 90 245 216 11 75 209 74 230 40 254 156 85 120 154 122 241 141 49 119 157 41 94 234 160 92 159 212 163 158 6 246 122 200 170 243 178 166 168 99 130 6 168 169 50 102 204 216 141 232 118 170 43 135 54 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 177 50 155 174 78 239 247 13 111 159 67 150 157 92 158 245 175 184 15 5 160 70 49 157 214 180 216 13 168 85 90 247 74 86 204 154 92 174 52 205 233 244 198 25 77 167 247 251 134 23 103 113 25 49 122 123 38 179 157 89 157 250 84 10 127 163 44 240 17 72 88 126 68 173 11 117 193 92 193 157 103 244 247 125 120 254 62 189 43 89 177 192 2 232 100 78 222 204 174 134 239 111 145 19 108 13 184 90 180 88 43 70 165 211 91 26 158 47 106 195 255 43 83 126 50 47 106 86 238 242 185 56 243 74 27 187 114 94 173 219 239 232 30 179 212 137 93 3 25 74 125 74 197 239 157 160 233 42 219 143 60 163 237 50 26 212 176 38 163 74 221 163 235 165 106 20 5 79 181 246 77 64 226 209 175 4 35 48 224 19 224 165 79 223 91 137 250 83 137 202 247 183 176 135 134 88 211 66 94 6 13 117 122 249 101 133 30 144 92 167 215 193 187 157 93 133 239 157 253 100 19 174 223 252 100 19 46 176 165 151 47 132 160 212 120 88 69 10 162 102 39 118 209 235 79 187 95 180 166 147 29 139 72 138 36 123 232 37 16 59 149 107 24 231 116 143 55 222 129 223 109 188 131 197 145 124 242 250 8 157 100 123 97 161 6 222 138 181 94 163 212 31 133 199 155 22 162 218 142 69 167 134 53 28 202 139 166 209 66 114 93 87 183 250 172 61 168 95 185 154 209 195 83 65 188 19 187 134 102 40 248 48 8 32 32 30 133 217 111 30 85 215 53 199 23 113 127 11 44 31 235 31 95 92 215 108 255 2 117 122 157 203 170 117 122 29 188 251 144 227 187 178 184 246 14 215 111 226 154 61 28 89 105 229 247 206 126 124 15 167 136 10 15 18 48 43 172 61 86 140 213 242 181 246 148 242 133 0 168 74 151 216 170 11 179 221 47 178 6 155 222 141 15 189 212 122 77 214 208 92 247 24 122 67 20 229 76 195 255 177 195 91 85 245 17 58 23 124 107 5 42 94 56 34 182 144 92 87 217 154 92 13 46 168 239 88 84 106 88 129 53 11 206 83 107 189 70 25 139 117 92 29 148 49 231 131 32 173 158 151 113 39 142 246 109 191 18 196 163 47 241 7 81 191 157 148 85 216 149 163 42 171 65 201 189 68 78 90 215 174 63 95 168 26 91 20 35 140 13 203 141 52 254 58 189 14 94 28 106 124 194 21 22 53 157 76 16 202 71 249 173 129 12 18 124 124 0 169 173 194 195 184 194 66 87 123 54 91 117 81 70 169 191 184 3 181 46 49 138 180 36 113 70 200 14 237 57 180 199 2 135 73 72 103 41 92 247 152 213 14 205 224 158 53 176 234 31 62 67 195 127 35 199 195 117 246 88 1 220 90 161 233 36 17 159 35 42 60 200 6 25 30 3 223 144 171 115 82 201 118 185 49 84 106 4 62 74 184 186 109 24 17 62 42 167 171 227 198 35 137 162 40 174 233 10 201 233 91 70 166 104 196 115 215 169 245 53 245 28 213 42 106 81 202 188 150 38 154 134 232 38 215 253 38 80 234 136 227 187 231 138 155 76 174 211 91 26 222 81 148 225 170 49 42 252 212 16 171 135 32 175 154 59 164 26 159 180 21 143 88 125 211 73 149 206 176 192 91 5 81 132 63 222 113 16 168 81 189 90 13 72 232 30 243 251 228 247 221 153 149 213 7 241 214 158 86 182 138 69 115 66 146 4 188 67 212 90 57 190 233 74 84 75 182 203 11 171 162 6 151 219 116 117 129 157 138 25 112 161 171 203 183 186 234 11 47 169 79 239 236 177 29 180 44 46 107 161 16 85 100 137 115 131 79 72 77 103 29 17 52 61 45 41 239 43 216 191 232 253 147 104 50 193 127 185 78 175 131 119 247 47 114 124 87 214 81 110 61 183 14 71 73 85 249 1 59 147 152 39 170 18 143 7 132 106 44 172 212 25 118 240 238 102 241 199 179 254 207 6 237 153 112 191 101 143 172 168 250 36 19 245 224 186 199 86 12 71 84 28 89 241 115 66 90 31 196 79 135 49 112 231 106 58 4 252 152 155 168 114 252 177 29 142 34 110 169 84 85 83 67 103 156 156 26 114 11 199 118 101 167 134 164 65 236 219 152 177 24 153 194 152 70 232 18 67 43 213 150 35 139 91 74 150 184 242 84 101 253 39 118 57 45 212 51 7 9 68 238 109 168 211 187 212 117 253 117 122 29 188 251 144 227 19 182 152 63 206 221 48 187 149 32 148 111 203 255 247 9 162 210 234 227 14 104 213 120 17 240 171 117 137 89 245 208 12 38 147 16 183 238 167 29 139 187 95 148 53 52 215 61 102 181 208 192 48 55 135 255 107 215 156 85 213 7 240 48 135 183 93 16 68 58 212 248 230 130 228 135 28 207 106 177 100 119 208 47 23 30 43 158 218 80 168 161 71 85 86 243 228 83 142 231 60 249 148 92 50 168 29 117 166 187 97 116 180 99 26 213 94 8 122 89 220 82 178 196 133 109 67 212 43 212 210 55 180 2 188 254 188 35 139 227 6 44 124 250 129 58 189 197 105 22 153 78 175 131 119 247 186 42 124 20 94 115 224 220 109 229 124 148 88 62 238 150 146 208 170 143 94 253 221 49 129 92 151 24 35 129 193 211 205 185 148 9 38 152 164 143 37 167 123 44 50 192 184 85 136 170 62 136 15 221 142 46 8 99 48 1 143 53 129 122 216 35 170 10 111 235 103 133 246 78 224 163 215 79 43 169 169 81 202 236 147 173 16 146 239 32 130 174 16 149 3 162 6 243 17 197 44 206 204 203 151 197 45 37 75 92 249 180 210 238 91 83 95 96 253 121 138 171 43 155 250 98 247 173 185 95 57 138 235 52 157 222 210 240 34 163 85 169 242 43 135 231 206 142 97 112 146 125 178 73 173 184 232 232 30 91 243 77 44 66 170 143 46 222 78 116 17 241 156 224 199 119 170 5 72 151 4 219 4 106 148 230 188 172 133 7 252 172 69 137 12 186 239 156 250 18 133 158 76 210 205 18 223 128 12 48 68 88 40 169 107 143 218 181 167 182 184 148 11 133 78 111 23 85 167 247 123 134 23 103 113 117 122 10 82 232 30 119 107 213 167 82 120 39 16 214 117 26 90 224 91 154 243 30 217 222 51 39 159 165 122 221 121 121 178 184 215 147 37 174 60 85 133 142 104 78 91 185 166 232 174 245 116 122 191 127 120 49 227 32 99 151 99 253 171 245 93 70 11 221 175 213 66 168 34 93 1 97 91 74 22 183 152 172 250 68 213 189 91 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 86 6 131 101 115 123 76 43 24 51 86 72 11 13 93 89 80 186 65 9 143 62 251 115 159 189 166 255 160 198 149 250 224 252 51 106 89 70 92 217 218 115 184 226 247 61 109 49 170 28 38 212 250 140 86 217 25 149 194 65 30 201 188 63 107 92 43 93 198 54 121 14 15 239 239 190 147 190 29 187 49 138 195 234 103 116 221 79 73 87 23 55 246 97 239 108 124 49 8 171 236 173 201 32 232 169 245 206 198 62 36 93 101 12 157 55 200 218 216 157 191 87 175 73 8 188 20 101 63 222 166 209 1 76 35 149 224 255 62 29 124 199 255 189 243 10 237 143 210 173 177 8 180 14 93 218 210 10 112 177 77 53 77 173 2 85 141 100 73 250 178 160 54 49 237 253 212 160 251 101 30 199 188 127 89 189 71 240 240 254 238 187 104 237 79 160 110 135 212 51 231 213 173 82 58 94 16 21 215 107 95 39 89 117 117 113 35 236 225 231 112 245 35 10 16 226 74 191 135 159 139 168 29 50 214 120 165 153 241 235 108 62 215 255 79 106 170 174 5 217 204 245 15 216 99 89 157 178 233 166 131 172 157 33 149 218 161 43 240 115 90 47 252 237 236 222 215 11 68 145 125 207 225 50 158 160 6 65 28 131 89 13 109 153 148 174 0 136 112 18 174 99 15 35 198 60 39 120 187 207 83 75 120 150 159 96 229 166 42 87 91 44 101 124 145 143 54 226 183 66 255 72 41 227 182 164 107 106 149 200 217 112 153 187 68 190 85 40 50 113 122 120 135 168 57 233 213 210 201 42 116 113 97 153 47 44 234 17 10 12 18 29 90 91 191 175 9 48 207 62 253 236 211 168 167 214 156 23 21 243 127 140 129 133 120 78 41 102 239 196 131 251 195 64 113 213 168 135 205 209 254 70 85 213 157 191 151 119 28 24 40 183 23 184 97 59 203 139 28 19 240 15 62 210 124 84 134 23 99 124 2 212 119 7 50 160 198 247 18 181 101 105 84 93 42 230 33 95 92 149 87 5 4 25 15 71 123 10 143 13 167 232 93 129 172 94 208 219 5 157 5 221 133 223 201 90 53 204 212 237 184 116 124 145 143 54 206 111 89 72 200 206 200 235 223 127 97 233 189 14 191 172 219 254 254 79 64 191 61 237 171 132 184 196 11 109 121 94 97 107 228 191 19 186 184 241 69 252 46 190 168 210 197 117 244 139 238 122 224 174 7 28 93 35 217 165 185 160 104 87 118 252 40 235 238 58 212 44 149 29 227 54 30 201 245 65 147 235 223 137 74 231 194 141 239 70 97 156 22 226 222 92 11 8 226 130 119 169 248 87 215 244 166 101 120 62 118 161 60 231 235 63 124 253 135 182 212 38 105 95 22 190 113 134 122 235 12 207 240 148 201 93 11 101 178 82 95 196 55 8 169 17 124 38 32 99 26 42 143 107 21 214 128 52 102 212 241 200 44 74 32 171 85 151 248 220 25 95 196 104 147 248 92 49 22 65 164 132 238 238 232 26 249 149 191 249 181 165 247 186 117 92 183 253 45 137 76 92 207 156 94 231 234 126 18 212 80 185 104 114 195 201 42 116 113 97 48 175 131 102 84 234 226 58 15 223 77 85 249 197 59 22 113 212 62 181 101 116 139 117 185 77 217 207 89 195 214 65 17 62 134 24 142 128 225 171 254 41 46 20 44 249 160 59 201 166 239 67 2 218 98 29 119 219 106 69 7 41 248 212 87 176 226 190 197 31 207 13 133 198 70 211 171 64 254 115 52 141 162 101 20 162 54 94 228 181 81 57 111 73 125 52 200 120 60 251 147 213 46 213 66 63 162 150 66 213 194 223 171 235 35 136 154 36 145 21 229 72 120 236 6 46 120 57 44 149 204 97 33 174 82 8 84 232 112 103 20 100 53 186 255 137 165 247 250 120 66 183 253 101 138 142 143 252 2 178 46 76 55 3 64 165 42 239 158 10 21 65 115 100 117 116 116 3 143 5 30 83 235 226 86 85 97 224 139 7 82 85 124 150 143 73 9 120 24 71 182 7 223 131 36 84 174 252 195 235 253 241 173 159 172 155 194 27 235 157 21 35 95 156 249 73 70 247 77 194 140 246 95 88 245 64 102 245 111 247 217 194 81 176 73 68 205 250 127 73 178 190 73 63 124 247 37 142 191 247 165 36 219 114 28 127 234 143 23 9 165 158 185 25 123 156 159 137 244 204 69 212 219 78 196 184 220 27 119 222 149 243 178 113 24 29 113 233 63 213 3 237 233 226 68 157 216 189 125 173 125 7 111 149 47 96 211 163 170 67 84 177 105 9 157 172 241 60 81 253 82 123 92 121 89 199 233 199 7 138 239 20 70 193 154 242 81 21 74 107 104 251 202 251 156 237 175 94 63 85 115 58 217 69 135 253 124 29 93 220 214 252 86 3 242 0 21 41 90 124 72 221 106 115 87 246 225 231 2 11 145 124 233 72 39 127 124 212 238 111 145 130 251 242 61 100 124 131 223 188 106 32 131 35 226 249 84 231 255 14 218 37 159 79 225 200 9 87 8 250 225 33 160 78 35 30 199 119 204 49 91 105 127 188 72 40 189 240 83 86 189 249 220 230 115 172 250 133 159 218 91 61 212 201 136 138 129 169 24 227 55 159 179 231 149 49 255 7 200 179 190 133 255 84 93 65 32 71 212 230 143 155 236 178 253 51 192 149 165 170 67 84 24 215 187 249 108 82 189 221 149 67 86 57 81 253 28 92 86 35 220 155 160 240 78 7 222 211 143 106 252 203 135 49 181 47 238 115 142 108 0 162 82 149 207 201 11 37 94 115 49 147 174 142 110 85 213 106 198 15 164 168 248 44 189 120 125 255 133 102 151 180 127 87 246 124 74 117 75 216 24 119 254 158 173 112 148 237 253 208 231 83 189 179 109 44 240 60 156 130 55 22 15 60 214 6 143 223 255 10 136 135 4 200 187 175 255 16 157 133 213 91 7 195 82 60 38 148 128 162 112 253 7 247 63 184 31 239 6 201 39 219 239 44 176 208 153 5 137 239 142 92 205 59 14 236 239 204 6 22 202 53 170 98 72 36 228 51 199 35 184 17 81 147 52 3 92 236 184 226 25 248 95 129 239 167 7 25 215 62 200 47 167 121 119 227 79 186 13 167 114 68 13 57 169 31 239 4 151 23 89 85 68 93 234 224 152 9 206 137 195 250 164 162 64 115 202 229 232 93 217 193 191 43 39 85 97 76 125 219 251 12 104 131 154 114 204 85 177 21 221 223 231 39 55 186 58 186 186 115 85 124 107 27 41 72 250 128 64 167 244 225 136 241 104 223 78 190 113 29 158 35 127 232 155 207 181 193 56 140 239 121 173 203 173 224 88 178 199 207 197 177 35 246 182 19 119 253 217 10 180 49 33 149 237 157 137 198 23 82 39 55 226 231 102 200 117 227 215 147 27 187 178 48 138 249 190 191 221 112 22 164 33 87 136 186 195 150 87 43 78 109 217 112 182 92 163 170 160 154 45 135 105 111 68 36 207 0 163 227 242 103 250 217 160 203 133 37 157 37 239 188 195 144 248 109 202 237 86 128 93 148 204 177 156 153 114 225 119 42 178 202 90 222 125 191 249 121 155 43 19 76 187 10 78 190 228 111 231 117 169 106 5 218 125 206 120 116 135 244 149 147 162 131 41 108 83 159 239 116 117 113 245 168 218 120 177 251 210 233 109 160 78 7 121 75 204 85 170 5 160 79 110 68 98 131 104 102 125 235 107 188 62 206 54 26 222 15 157 117 192 102 84 239 37 254 144 248 195 192 123 135 246 20 166 32 60 241 144 174 184 7 146 250 219 14 109 106 3 188 164 70 205 31 99 194 109 85 190 27 195 175 171 236 8 161 249 99 223 242 59 176 119 21 138 237 56 158 130 64 100 71 185 70 85 65 181 252 38 143 169 130 32 201 231 26 234 209 203 61 110 240 113 213 53 93 105 80 188 136 8 249 125 167 122 14 234 58 185 107 226 188 182 145 221 45 188 196 202 147 187 9 206 154 108 42 39 85 155 143 122 227 97 120 171 87 133 181 212 14 70 214 100 90 186 184 122 84 237 190 4 78 82 147 115 43 146 136 35 171 249 248 30 32 119 3 206 192 122 103 105 58 183 176 77 66 7 132 192 113 248 191 158 116 141 250 77 208 13 252 108 35 144 168 94 214 39 71 153 223 163 140 42 94 218 116 219 123 141 156 216 213 61 167 114 69 253 185 234 82 147 186 110 157 14 81 249 36 97 100 74 108 196 48 50 37 159 174 84 218 138 94 138 132 212 221 1 60 211 126 103 167 63 214 79 243 102 42 85 215 94 243 198 63 252 156 58 172 189 78 162 138 158 148 174 43 155 111 182 91 224 80 190 85 210 115 146 124 231 81 147 187 82 39 93 231 86 243 26 45 76 41 72 13 157 75 191 228 144 158 13 109 89 203 213 110 181 92 177 191 52 125 89 169 235 86 211 68 189 11 206 104 201 205 248 82 240 169 186 234 59 103 162 5 213 45 169 251 39 16 133 51 97 215 161 230 77 168 12 68 173 104 163 125 7 31 180 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 25 51 102 204 152 49 99 198 140 253 255 107 184 42 200 154 52 237 96 76 230 36 129 98 217 9 170 242 156 214 85 234 236 178 235 52 92 23 4 100 116 156 215 214 39 158 255 174 62 133 16 72 200 132 124 213 46 150 220 43 89 43 47 135 71 157 231 121 154 206 243 50 197 79 67 87 118 25 254 31 211 242 185 51 118 27 29 44 171 39 107 105 97 229 207 202 216 200 12 173 244 165 87 179 191 137 140 20 11 79 54 223 175 69 244 61 72 118 5 10 36 76 176 108 185 120 73 190 129 3 232 186 141 23 27 47 134 152 125 5 138 14 94 93 232 218 248 209 4 211 120 140 153 92 51 28 212 232 12 230 201 174 53 175 231 32 176 6 164 6 255 81 209 84 29 38 71 231 57 65 212 121 94 142 248 182 175 250 255 105 228 149 125 79 220 243 91 53 222 177 198 119 113 165 52 44 115 12 74 74 215 214 73 46 109 121 69 212 94 235 19 37 136 205 22 150 39 86 8 241 66 126 189 100 129 215 175 137 206 14 125 227 42 22 254 106 247 173 42 135 9 126 153 200 117 3 193 143 84 229 174 107 134 245 161 25 92 102 134 75 208 172 204 42 182 174 89 93 155 192 243 157 217 95 118 39 73 18 217 214 203 168 230 186 225 20 235 127 246 233 145 169 54 210 88 6 154 8 151 111 255 231 39 159 106 38 117 6 205 236 201 167 110 255 103 24 5 250 232 84 5 93 157 111 237 5 242 132 218 140 254 198 57 148 14 171 169 243 92 42 190 119 86 72 211 150 191 124 16 204 9 197 62 140 254 58 242 53 69 16 70 248 39 74 4 13 191 137 203 28 253 201 157 96 238 182 196 3 169 33 235 242 65 166 175 152 216 195 234 174 32 201 10 196 217 231 101 126 192 199 95 59 170 204 240 17 53 231 215 177 207 138 169 26 251 140 224 184 233 149 139 109 95 38 254 79 247 191 198 25 171 86 105 218 197 221 235 60 21 125 34 171 233 157 141 186 240 176 104 87 57 214 88 177 54 246 208 75 24 31 80 198 163 13 71 133 34 235 198 173 163 63 185 243 47 193 247 148 229 79 175 94 216 247 4 235 104 127 67 166 72 225 216 208 76 251 27 172 99 223 19 171 23 172 105 194 8 204 80 24 165 170 106 223 227 255 41 125 251 251 208 81 157 81 213 166 141 137 35 116 77 30 167 8 157 103 190 176 57 255 12 198 212 120 71 119 151 130 239 202 30 217 126 100 59 95 229 74 43 223 17 8 82 225 187 178 184 60 252 245 31 30 235 59 182 3 101 7 162 140 18 219 12 222 194 53 47 81 1 115 165 47 53 186 178 78 91 242 3 201 33 19 180 97 43 132 78 137 80 207 98 43 252 209 186 146 233 73 198 125 180 251 210 224 45 131 183 116 95 226 113 147 24 85 61 150 77 75 220 202 158 217 6 89 199 220 15 254 53 110 111 158 225 42 202 199 218 238 118 151 222 118 183 98 142 202 138 123 93 184 226 164 124 148 12 126 9 90 5 141 24 31 168 123 45 232 255 143 136 250 190 18 184 235 129 135 94 136 253 155 255 70 86 118 105 207 181 51 144 153 89 97 141 217 2 210 252 152 244 171 61 30 54 110 140 173 248 100 83 59 156 45 159 205 180 94 59 176 31 117 234 170 170 94 13 254 124 240 191 61 250 243 95 200 119 43 176 250 34 139 142 248 202 224 105 127 221 38 52 161 243 108 147 35 180 119 130 147 105 237 251 114 124 87 22 150 244 135 156 51 85 248 36 219 253 34 74 7 236 126 145 138 231 79 64 93 126 7 116 24 27 206 226 82 74 86 179 169 77 72 191 119 16 58 204 166 147 188 236 213 64 63 255 5 254 62 235 79 165 203 233 63 232 118 100 114 186 178 31 116 83 167 42 36 237 38 8 126 49 62 137 218 19 192 168 29 171 228 214 221 90 125 94 5 249 5 110 205 76 40 244 198 93 194 102 42 170 38 158 42 232 81 158 146 97 223 73 20 202 199 240 208 234 157 132 124 148 140 51 212 42 176 151 139 247 79 141 162 234 63 141 170 172 250 231 145 193 255 114 255 63 182 42 241 182 179 52 136 71 121 122 91 228 107 47 116 228 107 151 130 81 3 150 207 207 150 181 207 246 87 67 191 67 18 217 75 186 107 47 221 250 120 167 188 53 215 124 249 228 83 206 42 96 22 146 207 207 185 206 179 152 81 177 6 220 194 4 226 166 69 25 190 119 22 148 155 26 156 121 146 10 111 11 145 216 75 171 89 3 31 113 84 248 98 170 250 227 19 223 36 217 15 206 243 207 45 47 80 116 170 115 29 90 78 238 155 75 206 28 219 81 190 185 42 62 167 137 221 162 236 137 221 229 85 153 64 187 208 143 34 74 81 59 162 196 207 194 185 38 188 10 138 76 120 23 210 59 43 84 227 11 47 43 191 244 218 79 221 232 181 159 202 195 22 62 232 187 15 12 6 40 84 178 155 254 63 196 183 68 94 78 42 169 39 194 112 246 239 183 246 141 254 36 73 164 182 245 87 214 144 245 23 212 87 26 126 211 11 61 252 230 74 124 208 127 1 212 95 137 243 85 84 101 193 196 55 214 176 80 17 96 255 14 59 67 89 106 107 224 61 28 223 115 223 85 91 171 229 109 223 153 45 188 250 198 59 176 125 59 179 50 124 247 165 141 119 20 182 128 28 111 171 30 49 30 131 112 145 48 21 30 130 198 126 62 134 240 48 219 31 223 245 109 18 183 245 10 64 74 239 114 199 159 243 99 217 183 52 162 14 205 156 216 5 226 63 113 127 197 14 247 92 213 25 85 85 233 73 86 63 50 133 229 143 76 169 4 130 28 47 198 43 208 168 234 132 190 60 12 22 189 220 135 94 84 245 219 219 13 165 63 116 169 106 29 92 18 208 74 114 163 184 3 220 210 128 220 127 167 152 66 42 193 152 179 254 142 61 107 255 109 252 168 12 191 254 88 239 44 110 125 97 191 222 1 169 172 213 146 185 73 97 249 161 100 236 112 215 183 246 227 108 241 108 31 123 92 239 250 54 118 56 148 164 82 181 170 234 133 159 186 183 173 178 210 178 153 18 228 185 127 102 165 49 185 5 221 70 124 213 143 194 59 228 101 243 61 92 68 194 223 26 11 44 68 165 58 207 136 143 162 114 241 152 120 81 144 84 226 151 142 146 42 124 123 110 182 137 83 10 57 126 224 61 252 125 211 149 190 201 71 126 17 37 106 251 58 68 133 169 106 173 60 211 225 158 171 58 163 170 106 79 37 140 254 240 10 239 36 84 56 33 106 255 236 211 219 118 109 219 229 124 39 79 164 137 208 151 135 193 194 185 226 158 177 122 92 118 115 73 118 96 255 200 148 19 168 202 168 106 141 181 45 161 94 155 36 45 128 206 94 172 160 232 71 12 143 81 175 161 123 219 109 159 165 190 96 141 210 84 251 154 35 219 99 139 214 158 173 227 184 157 159 124 110 226 46 223 170 78 142 36 222 247 30 79 11 199 214 196 251 201 17 171 154 74 85 86 191 225 236 202 188 155 116 44 30 223 233 143 221 253 226 106 198 103 182 45 247 133 254 251 109 239 173 129 240 78 86 182 163 243 12 132 157 22 122 204 254 58 207 28 159 192 151 40 211 206 153 42 124 49 85 213 120 144 61 143 89 177 214 107 42 252 131 251 249 116 171 13 206 24 77 179 254 207 6 247 78 200 229 78 221 68 85 207 104 75 153 171 242 32 216 158 88 40 229 136 132 82 118 241 33 127 177 35 66 95 30 6 151 28 171 99 191 120 239 143 128 82 157 167 183 141 31 197 185 137 140 170 111 182 141 31 69 53 68 103 26 62 144 25 63 250 102 155 164 169 3 88 81 135 168 81 233 203 148 124 64 139 34 211 213 161 77 145 151 163 236 200 118 101 67 215 62 244 210 109 215 30 79 36 72 25 227 222 35 93 89 148 181 12 174 73 61 220 193 142 41 95 192 28 235 235 96 169 135 131 107 248 8 169 166 42 10 146 58 97 216 127 62 33 19 88 179 231 203 33 155 170 87 214 94 221 244 26 134 119 210 146 27 156 182 108 39 232 60 59 248 118 119 103 73 192 211 116 164 5 30 95 219 5 63 74 104 148 159 96 131 143 35 69 58 102 100 120 61 162 150 54 87 117 60 131 134 210 210 25 246 204 0 219 211 139 226 100 50 166 17 100 105 25 190 215 22 159 203 130 140 99 35 104 28 194 172 99 52 237 223 251 0 6 212 16 63 27 60 180 231 208 30 72 186 164 224 187 70 89 111 180 251 86 112 191 78 241 158 14 59 132 221 183 74 92 17 251 192 32 246 182 137 207 255 26 62 132 96 11 40 138 136 233 116 184 51 123 219 62 226 166 138 193 227 59 59 22 113 134 186 70 177 137 135 120 221 52 144 89 99 171 7 227 8 137 181 83 191 36 119 191 46 160 189 133 133 151 100 221 208 97 42 107 163 171 243 124 163 240 81 22 213 44 191 237 43 120 241 146 185 253 115 25 94 143 168 75 223 171 210 230 170 252 25 80 94 220 233 238 110 128 79 214 174 3 76 53 109 173 73 219 119 108 63 45 46 202 178 211 219 210 247 74 56 31 11 22 167 70 212 1 195 234 133 213 11 20 253 66 46 45 58 50 133 1 192 200 148 221 33 208 206 234 204 5 47 65 202 35 98 213 219 95 109 37 204 73 196 40 156 15 148 226 36 124 188 80 90 91 175 247 165 160 49 189 71 172 123 94 231 25 35 26 181 174 242 242 196 111 62 215 51 215 245 109 232 119 15 63 39 199 99 120 172 163 183 91 252 94 149 58 87 149 107 47 151 30 96 39 61 255 176 208 126 214 165 198 234 250 6 87 210 40 21 245 103 81 143 182 170 98 102 143 118 55 85 142 122 201 232 77 254 51 181 145 169 198 43 216 141 145 75 231 58 207 24 209 52 124 71 241 29 16 67 16 116 170 249 4 65 203 43 75 244 255 202 168 250 22 123 64 169 202 208 198 150 11 177 91 48 248 53 237 240 253 177 255 7 69 155 124 1 121 110 52 77 0 0 0 0 73 69 78 68 174 66 96 130) asByteArray
]

{ #category : #uploads }
OHFileRequestHandler >> imgglyphiconshalflingswhitePngContent [
	^ #(137 80 78 71 13 10 26 10 0 0 0 13 73 72 68 82 0 0 1 213 0 0 0 159 8 3 0 0 0 152 211 179 123 0 0 2 217 80 76 84 69 255 255 255 0 0 0 0 0 0 249 249 249 255 255 255 0 0 0 255 255 255 253 253 253 109 109 109 0 0 0 255 255 255 255 255 255 255 255 255 0 0 0 0 0 0 255 255 255 240 240 240 254 254 254 246 246 246 0 0 0 252 252 252 0 0 0 0 0 0 255 255 255 255 255 255 218 218 218 0 0 0 194 194 194 244 244 244 255 255 255 255 255 255 244 244 244 247 247 247 255 255 255 0 0 0 0 0 0 179 179 179 253 253 253 0 0 0 226 226 226 176 176 176 255 255 255 255 255 255 251 251 251 231 231 231 254 254 254 255 255 255 0 0 0 237 237 237 0 0 0 207 207 207 0 0 0 253 253 253 246 246 246 237 237 237 251 251 251 231 231 231 250 250 250 225 225 225 146 146 146 254 254 254 254 254 254 193 193 193 152 152 152 116 116 116 225 225 225 208 208 208 0 0 0 243 243 243 187 187 187 161 161 161 128 128 128 253 253 253 212 212 212 98 98 98 255 255 255 213 213 213 248 248 248 220 220 220 250 250 250 251 251 251 233 233 233 251 251 251 253 253 253 253 253 253 209 209 209 242 242 242 252 252 252 248 248 248 235 235 235 252 252 252 182 182 182 198 198 198 229 229 229 238 238 238 245 245 245 253 253 253 101 101 101 103 103 103 240 240 240 182 182 182 224 224 224 247 247 247 250 250 250 233 233 233 229 229 229 250 250 250 248 248 248 203 203 203 255 255 255 132 132 132 241 241 241 120 120 120 247 247 247 221 221 221 249 249 249 200 200 200 210 210 210 236 236 236 250 250 250 222 222 222 226 226 226 230 230 230 243 243 243 155 155 155 168 168 168 165 165 165 220 220 220 238 238 238 255 255 255 241 241 241 201 201 201 240 240 240 255 255 255 255 255 255 222 222 222 198 198 198 188 188 188 235 235 235 214 214 214 208 208 208 226 226 226 249 249 249 244 244 244 226 226 226 236 236 236 245 245 245 180 180 180 255 255 255 253 253 253 251 251 251 252 252 252 250 250 250 230 230 230 0 0 0 228 228 228 252 252 252 247 247 247 176 176 176 153 153 153 253 253 253 236 236 236 252 252 252 193 193 193 233 233 233 255 255 255 218 218 218 240 240 240 240 240 240 245 245 245 241 241 241 254 254 254 248 248 248 254 254 254 142 142 142 226 226 226 251 251 251 249 249 249 220 220 220 255 255 255 242 242 242 250 250 250 159 159 159 237 237 237 247 247 247 246 246 246 232 232 232 243 243 243 250 250 250 245 245 245 245 245 245 166 166 166 203 203 203 250 250 250 248 248 248 211 211 211 235 235 235 250 250 250 235 235 235 170 170 170 243 243 243 237 237 237 162 162 162 207 207 207 218 218 218 214 214 214 162 162 162 235 235 235 226 226 226 249 249 249 85 85 85 205 205 205 255 255 255 214 214 214 227 227 227 225 225 225 234 234 234 252 252 252 255 255 255 246 246 246 251 251 251 243 243 243 244 244 244 204 204 204 255 255 255 255 255 255 249 249 249 245 245 245 255 255 255 242 242 242 253 253 253 0 0 0 217 217 217 252 252 252 251 251 251 252 252 252 233 233 233 191 191 191 251 251 251 234 234 234 233 233 233 254 254 254 255 255 255 248 114 79 230 0 0 0 242 116 82 78 83 0 26 0 212 207 2 15 241 35 16 239 159 95 10 5 47 169 240 198 21 226 24 3 191 31 111 19 83 183 223 63 134 197 127 6 23 67 225 13 107 68 143 175 194 141 192 79 18 83 15 95 8 160 165 154 178 140 211 17 54 208 224 62 52 33 126 97 11 167 64 49 30 209 95 39 111 18 196 110 162 210 139 145 144 128 77 134 161 147 51 177 66 81 106 153 182 112 38 37 33 21 108 181 195 34 88 113 114 59 128 29 151 32 65 91 130 60 96 137 97 109 125 52 133 51 47 48 73 136 4 168 80 67 77 33 54 40 42 103 75 38 89 81 166 71 68 80 44 14 229 129 96 146 123 1 86 80 164 45 25 234 120 193 41 104 221 55 135 101 49 93 244 136 223 27 87 191 179 36 151 135 49 24 131 98 196 122 83 220 149 99 23 79 217 205 93 143 192 138 21 150 85 22 59 90 105 60 78 35 215 12 41 9 56 54 112 86 224 242 148 58 104 141 35 249 48 90 132 24 81 212 14 74 78 134 190 69 20 68 84 140 222 126 245 135 94 0 0 30 45 73 68 65 84 120 94 236 157 135 127 35 199 153 166 191 98 39 2 13 52 2 65 16 36 65 104 0 6 147 28 13 41 14 195 112 134 51 154 60 26 77 144 70 57 89 57 88 193 178 44 219 114 206 105 157 214 246 218 190 221 219 124 155 115 188 219 116 57 231 156 115 206 249 222 191 224 88 221 32 107 186 190 106 118 243 64 173 108 95 191 146 73 255 158 42 126 104 244 131 14 160 62 20 233 187 39 121 220 34 128 226 208 208 16 145 141 221 216 134 137 75 11 54 52 214 89 156 42 46 118 232 64 178 184 31 238 142 1 99 46 125 59 135 239 159 116 78 37 2 168 68 73 1 24 170 152 202 208 9 8 33 16 90 29 182 208 143 53 76 241 72 163 50 218 54 32 140 31 131 201 175 142 214 34 138 11 212 45 98 177 69 44 21 44 41 144 202 143 0 192 17 13 66 5 140 183 24 166 62 109 25 185 170 195 227 250 110 28 248 246 54 112 109 159 82 246 79 10 119 109 16 64 176 221 204 86 221 35 63 201 39 67 133 200 145 90 35 169 142 113 158 135 24 236 192 27 23 98 210 211 124 36 189 58 220 41 137 194 47 69 190 37 247 226 110 5 82 185 113 151 67 224 104 24 8 110 181 201 37 245 105 211 204 147 173 186 182 182 223 125 108 131 109 10 63 105 255 100 226 100 195 34 128 44 216 25 173 22 199 0 96 172 72 241 8 21 34 114 46 122 161 188 139 142 193 126 253 236 252 40 98 240 81 220 85 38 234 189 29 151 41 150 53 245 234 88 35 149 167 160 242 20 233 153 69 77 170 230 220 82 60 205 42 112 91 24 128 91 37 46 169 79 201 204 163 152 165 2 107 55 147 27 0 108 73 111 176 253 3 168 253 147 182 223 74 176 70 8 160 17 11 165 108 86 15 33 204 161 196 131 117 72 130 96 198 3 188 153 128 151 155 20 19 231 3 130 38 162 44 199 122 22 180 201 82 107 36 21 164 242 17 168 124 36 246 108 138 187 188 88 98 252 162 226 233 199 106 223 170 200 100 85 8 177 251 63 206 163 36 72 181 238 184 25 169 87 177 190 127 36 85 251 39 133 31 198 197 72 220 69 28 51 42 213 173 186 128 181 181 85 7 92 125 234 173 253 127 134 40 210 10 24 164 18 122 18 104 86 107 125 103 199 117 171 82 107 36 21 164 242 37 168 124 137 84 168 124 218 234 99 107 166 28 231 141 179 34 16 227 158 228 177 68 231 148 253 29 171 131 95 87 43 139 174 148 202 46 81 242 210 197 41 213 64 18 171 253 147 198 189 128 72 8 162 192 155 205 98 181 115 4 184 212 108 158 1 142 84 180 169 183 68 255 244 173 82 0 4 196 3 50 88 109 163 35 97 5 13 221 234 186 51 108 89 195 206 122 204 106 185 142 157 212 227 146 154 35 27 33 222 24 9 52 254 4 74 180 196 56 209 40 0 140 242 99 181 31 1 118 153 137 190 14 116 93 173 20 97 183 152 84 153 19 199 1 224 248 9 210 247 143 0 68 5 13 206 133 224 188 225 81 63 94 45 139 213 15 95 7 94 36 58 1 92 255 236 222 86 9 160 36 171 149 78 124 236 61 40 118 136 90 39 113 143 54 185 90 240 215 134 135 215 252 66 53 86 236 204 238 33 121 134 180 188 51 228 223 75 156 255 227 177 191 98 224 4 0 6 118 52 140 241 30 120 240 235 234 163 17 226 82 93 27 97 108 151 237 31 33 212 254 73 219 111 135 80 137 64 197 116 165 228 86 3 121 148 186 238 17 224 76 239 255 217 170 15 109 108 181 218 191 73 168 85 98 124 91 42 176 182 6 108 107 101 39 42 190 87 100 238 5 26 192 221 100 224 179 240 24 239 68 183 211 157 125 92 87 155 131 95 87 223 157 180 249 182 164 114 208 78 218 63 153 248 219 118 222 171 29 193 219 178 88 37 167 142 48 117 135 246 111 117 105 42 132 252 74 86 24 183 128 198 166 135 98 37 134 125 244 227 23 136 105 53 73 165 89 108 78 159 69 45 27 119 23 208 207 130 251 102 95 87 51 109 254 5 73 229 224 133 196 253 147 133 151 45 140 109 131 202 24 172 178 81 41 147 83 11 181 214 107 180 127 171 84 67 8 55 234 237 25 109 164 60 34 196 244 220 140 135 98 139 84 124 236 198 39 166 213 36 181 210 152 159 163 243 243 214 82 38 62 165 234 79 13 112 15 156 245 186 154 190 249 133 234 54 221 30 172 22 210 246 15 231 250 189 116 177 168 238 165 83 173 142 78 92 169 215 175 76 140 238 109 213 248 92 200 2 206 18 209 202 196 114 64 166 4 51 158 117 141 84 10 98 55 250 211 116 46 53 46 113 169 244 200 51 178 114 48 252 61 153 56 84 144 194 7 127 191 170 105 173 74 169 92 235 200 54 117 70 10 148 178 127 82 184 51 50 94 247 26 237 241 17 39 197 170 138 243 192 237 14 177 120 136 226 73 171 9 239 210 70 132 56 79 123 37 56 173 158 107 74 154 211 77 83 129 200 180 19 100 226 66 69 100 230 209 232 160 239 87 157 130 67 89 195 247 79 58 47 79 140 78 47 151 73 139 16 234 95 61 189 128 120 70 69 148 209 33 26 32 205 61 165 230 105 58 111 193 126 27 146 161 183 32 121 254 63 182 154 39 183 154 39 183 154 91 205 147 91 205 147 91 205 147 91 205 147 91 205 173 150 232 187 46 185 85 31 62 177 36 247 80 150 198 166 138 99 37 134 93 160 219 5 92 99 169 180 58 233 124 9 253 44 101 175 83 156 90 44 145 111 154 191 88 114 237 228 206 203 88 186 33 235 82 230 148 22 199 198 22 15 242 64 225 90 248 118 130 32 7 135 48 212 231 62 0 63 193 42 231 174 13 212 60 240 254 213 31 0 30 124 16 248 129 20 171 188 78 54 254 48 250 185 59 123 29 175 6 20 97 158 15 100 179 234 50 24 5 212 233 118 43 68 228 243 94 116 224 224 250 209 91 113 0 33 4 8 242 219 158 86 125 200 248 102 171 156 219 168 207 143 142 206 215 89 255 234 101 224 165 151 128 203 41 86 121 157 108 124 22 34 12 102 247 85 199 3 178 113 136 157 64 235 136 199 188 152 52 89 45 2 152 26 179 89 253 205 45 33 182 54 97 147 158 138 66 58 111 37 241 22 74 164 219 3 73 177 180 151 85 31 81 124 163 85 198 75 168 79 4 160 96 162 174 61 92 11 253 180 18 173 242 58 8 235 48 190 176 192 120 11 22 133 177 80 97 243 137 204 117 136 30 2 64 156 187 33 231 187 75 134 226 3 14 16 80 207 100 213 120 104 119 49 62 215 36 106 206 141 179 147 118 23 144 246 90 100 224 232 16 153 120 241 171 213 83 154 85 65 8 197 38 91 85 82 1 223 100 149 253 55 240 195 184 157 194 122 183 107 253 171 47 3 152 156 4 240 114 162 85 94 7 172 142 228 29 160 163 243 151 119 58 73 46 224 21 86 199 174 24 235 244 255 99 62 113 238 132 156 237 46 33 19 183 122 83 219 114 38 171 179 213 50 133 41 87 103 249 9 190 133 82 9 45 206 105 227 81 9 56 191 231 216 251 80 97 92 208 158 215 85 37 149 105 221 161 166 254 85 16 239 95 61 5 224 195 31 6 112 202 248 9 28 155 76 117 160 234 40 238 158 2 78 185 26 63 134 159 160 48 63 129 195 134 58 93 189 206 172 228 134 212 20 207 116 172 66 37 147 85 124 153 250 249 178 161 78 115 28 24 111 114 78 255 185 102 182 250 9 4 248 44 187 80 16 9 1 33 18 173 22 4 118 34 10 89 172 54 188 104 76 239 95 173 0 64 16 0 64 133 98 233 183 115 17 175 99 3 182 172 163 113 103 26 152 118 52 14 124 157 194 124 29 48 108 207 159 208 235 212 36 15 83 140 245 57 141 142 238 242 98 202 177 154 209 106 35 142 159 163 126 158 131 193 210 207 3 63 111 178 247 125 30 145 145 131 240 125 55 115 65 80 109 58 73 86 185 61 110 149 247 175 10 33 244 254 213 123 177 155 123 205 221 104 188 206 69 224 162 170 163 56 1 164 115 0 232 16 117 0 128 205 111 76 174 24 235 200 84 240 36 241 132 245 7 59 86 221 250 185 173 115 27 245 246 99 113 236 68 19 1 7 166 51 240 248 184 241 12 252 7 219 17 224 188 130 15 51 46 68 6 171 66 136 20 171 233 253 171 179 0 26 66 52 0 204 38 236 21 86 39 216 220 12 84 29 197 9 96 245 1 224 189 68 239 5 0 54 255 153 158 154 207 183 243 113 253 121 249 106 251 7 56 86 157 137 213 230 42 235 214 3 237 88 37 253 179 4 155 64 115 171 92 222 106 114 78 181 7 36 224 124 246 61 15 53 2 254 206 134 32 39 236 109 85 194 20 171 105 253 171 75 253 143 105 29 2 128 37 67 153 201 73 240 58 115 115 97 29 198 133 96 28 42 96 243 29 181 61 25 250 108 189 247 41 62 200 117 213 152 77 101 117 83 27 154 155 183 168 73 242 95 206 79 247 136 76 252 163 95 169 125 144 111 38 169 237 28 192 106 122 255 234 221 0 112 157 232 186 254 123 2 168 164 214 225 220 108 117 144 58 4 79 241 193 174 171 198 204 41 171 115 164 37 24 81 64 227 205 36 222 60 93 102 155 9 18 128 160 120 79 37 133 247 80 67 98 104 114 50 163 213 244 254 213 26 0 188 159 232 253 0 80 75 183 202 235 112 158 102 53 189 78 195 171 51 94 29 29 111 171 249 169 250 188 93 234 101 178 74 202 234 193 164 105 208 66 152 156 52 54 52 19 134 128 94 116 2 239 127 141 135 117 217 178 254 85 214 140 58 71 52 39 191 143 242 50 50 89 234 112 206 235 136 204 117 166 71 39 24 47 80 121 217 52 63 161 254 232 46 29 213 230 83 66 132 80 95 15 62 145 18 209 235 25 27 154 73 12 9 49 116 51 206 147 247 66 228 201 173 230 201 173 230 201 173 230 201 173 230 86 243 228 86 243 228 86 243 228 86 243 228 86 115 171 230 6 195 93 238 179 33 215 54 55 7 40 170 199 103 11 175 164 165 139 138 121 131 176 64 134 148 12 29 52 62 81 218 242 32 223 213 86 171 70 173 125 94 88 215 135 236 218 188 136 146 213 106 141 181 30 166 101 22 247 50 54 9 76 158 179 208 37 158 242 89 180 71 226 104 1 11 251 179 154 108 26 137 67 173 125 173 41 211 226 60 10 136 33 218 69 160 244 240 199 69 189 80 231 90 21 87 90 153 189 140 86 43 17 254 64 194 134 16 207 82 13 53 6 123 64 111 117 24 151 201 144 127 134 7 52 178 130 21 178 38 133 0 132 152 180 72 133 209 1 172 54 247 101 181 121 32 86 19 139 136 221 128 8 24 3 152 86 197 165 214 193 172 190 18 225 99 113 90 132 222 146 169 114 236 211 22 74 198 231 121 66 234 230 121 7 158 211 17 136 70 122 209 15 245 70 20 78 162 36 162 16 143 72 29 98 200 200 213 16 179 42 17 43 157 106 213 143 113 242 209 141 206 192 32 218 171 29 152 107 221 191 85 224 88 132 175 3 108 186 101 1 183 2 236 196 246 190 31 196 49 147 213 202 26 218 100 8 224 48 100 94 245 45 145 66 37 137 131 157 125 15 234 12 156 248 184 123 89 245 161 23 153 37 114 199 42 210 106 53 65 107 53 166 117 16 171 179 34 204 44 183 58 126 233 210 184 225 89 190 220 8 126 10 104 153 247 251 3 196 83 65 157 126 191 173 54 21 30 236 12 188 144 102 117 193 108 213 135 102 181 138 123 200 181 81 116 65 84 72 208 90 136 107 29 192 170 138 198 173 47 0 95 176 184 213 83 159 238 188 110 225 251 185 10 177 117 22 39 93 98 249 93 124 109 96 171 66 133 241 196 129 193 207 192 161 30 74 44 79 36 237 193 100 117 93 183 90 16 115 174 13 192 70 76 223 58 169 196 249 250 250 155 97 245 248 139 192 139 199 153 213 14 194 204 26 84 52 207 111 224 126 98 121 24 63 119 112 199 106 230 187 165 214 65 156 129 133 216 40 128 120 249 93 132 194 134 16 166 250 133 170 102 213 237 182 126 4 97 110 214 167 47 158 169 184 191 94 200 100 213 218 178 246 99 21 31 216 218 250 0 152 213 135 44 33 196 22 208 49 169 248 105 28 38 150 27 120 105 95 86 75 64 105 112 171 205 131 57 3 175 208 222 86 105 37 97 59 11 213 24 175 76 1 63 137 48 74 31 147 42 185 146 154 197 170 53 220 28 182 184 85 209 15 183 138 147 39 193 172 186 120 94 238 178 54 30 226 86 91 165 26 94 32 22 224 123 246 101 85 153 200 210 124 151 58 48 248 61 48 135 187 200 100 219 171 111 135 168 16 231 42 74 31 147 26 113 37 149 91 173 198 245 89 195 78 184 152 46 115 81 132 76 139 117 100 154 91 50 215 240 5 57 254 73 253 243 58 87 193 110 151 212 200 255 208 217 2 22 18 142 202 109 30 153 88 24 108 165 218 131 190 7 54 215 33 24 108 143 78 108 135 217 86 217 213 167 75 85 188 164 164 106 86 227 92 74 37 169 85 223 138 157 223 66 176 142 76 99 75 102 23 225 98 215 21 246 62 22 97 26 147 61 210 98 155 126 31 185 82 93 97 71 37 91 157 250 247 215 106 115 64 171 60 105 143 91 208 165 42 94 46 100 59 85 73 169 82 43 235 79 15 68 152 50 101 202 220 182 229 32 250 161 81 195 227 78 51 169 52 34 49 163 133 221 31 210 248 134 232 103 163 48 224 250 195 7 117 6 22 148 92 135 20 228 73 125 220 193 227 208 119 70 86 216 255 25 52 121 47 68 158 220 106 158 220 106 158 220 106 110 53 79 110 53 79 110 53 79 110 53 79 110 53 183 234 182 104 224 44 210 183 85 114 171 174 93 172 24 22 186 93 76 94 191 151 167 131 37 74 142 187 68 131 198 247 105 31 201 173 186 207 30 71 209 212 157 13 223 180 174 47 0 219 37 61 39 113 138 195 165 41 200 217 242 231 58 140 143 81 203 60 191 88 161 46 171 229 39 244 163 135 91 149 64 249 80 18 159 234 208 1 196 118 195 47 201 188 5 176 161 136 242 184 62 47 20 57 240 77 216 183 221 152 85 215 62 121 201 178 88 199 64 125 179 13 148 12 235 235 70 162 180 116 1 220 103 94 130 219 26 118 79 92 176 158 211 184 119 118 130 112 149 207 31 175 122 51 129 15 155 75 53 105 5 164 33 36 80 62 148 196 129 197 22 25 2 128 144 185 39 6 210 17 148 86 198 155 172 148 162 76 158 28 50 114 24 180 250 64 164 85 77 195 201 75 195 250 90 175 245 137 185 229 54 14 27 214 215 5 192 116 119 140 235 167 159 194 166 16 98 228 132 109 223 49 226 104 124 244 124 201 7 22 93 125 126 185 48 26 248 192 5 77 106 65 0 162 192 180 2 210 16 18 40 31 74 226 0 138 221 193 173 74 17 80 54 56 7 204 67 38 121 114 200 204 215 137 101 29 125 173 106 26 142 95 99 203 74 189 63 234 73 48 172 175 107 234 219 62 21 194 154 171 87 153 139 30 225 248 9 198 251 139 153 175 233 124 161 66 190 222 157 225 46 34 84 69 88 100 143 32 13 129 12 212 56 148 196 33 99 119 6 181 42 69 40 27 6 206 74 41 202 229 201 33 206 19 91 87 34 173 106 26 95 21 212 195 225 208 162 101 88 95 215 208 5 88 66 59 164 247 27 175 111 176 134 79 48 126 63 172 58 80 189 67 227 11 40 46 178 237 182 177 27 91 183 17 142 145 145 242 33 87 113 163 37 223 29 212 42 108 101 195 192 89 41 69 153 60 94 136 75 229 90 185 84 149 54 48 214 29 3 46 240 245 129 35 171 181 248 65 92 253 164 193 53 1 59 82 109 198 127 116 107 100 194 27 47 56 26 127 167 7 41 53 126 130 191 160 172 94 48 218 32 35 229 67 107 26 103 150 166 6 182 26 101 205 204 121 41 141 178 151 177 205 182 191 145 212 186 210 0 176 54 196 165 170 60 128 40 63 198 215 7 38 201 245 245 117 127 238 65 132 225 86 159 146 245 109 48 94 104 18 157 46 151 116 30 204 120 82 42 244 215 97 244 169 39 246 58 5 44 165 72 167 124 232 14 197 141 150 170 207 12 108 53 122 132 59 18 56 43 101 166 35 98 39 35 124 251 125 50 198 15 31 119 40 124 75 99 150 74 189 13 200 108 54 13 235 3 3 128 182 190 174 119 249 139 94 130 213 143 140 111 215 7 24 151 105 250 156 7 51 27 5 2 72 211 26 13 234 82 9 24 150 142 204 148 15 57 138 27 44 89 147 5 103 80 171 214 176 58 78 12 156 91 53 83 21 195 246 251 137 82 135 157 33 162 167 228 91 26 41 149 231 93 22 128 250 156 105 125 96 0 250 250 186 109 172 29 146 184 78 177 52 208 165 185 178 227 118 209 96 124 59 102 30 172 40 174 180 70 239 108 116 169 4 132 162 76 212 56 148 196 195 183 90 35 189 65 239 150 164 79 37 213 192 89 41 78 185 85 174 53 89 234 16 209 101 156 188 100 150 74 206 69 15 141 51 100 90 31 216 176 146 254 199 60 200 120 183 199 241 157 216 201 157 3 241 228 182 101 32 20 149 64 249 80 18 7 218 167 207 15 254 206 70 250 84 82 13 156 149 50 83 161 194 183 223 252 206 166 47 117 136 90 176 126 240 154 67 230 4 51 141 199 212 88 202 122 188 205 211 85 15 168 158 14 226 120 245 92 3 50 141 115 171 3 241 228 182 101 32 20 149 68 249 144 68 46 231 141 201 229 102 66 79 38 101 110 221 39 105 200 229 82 37 143 6 153 63 70 121 184 86 115 83 126 36 117 136 174 109 141 156 119 40 41 193 180 114 148 186 30 111 179 48 42 68 129 237 152 213 105 33 51 189 58 24 79 110 91 22 66 181 33 115 202 135 66 228 112 62 221 163 3 72 84 217 49 242 232 11 59 246 56 77 215 106 110 202 143 164 14 145 211 164 239 188 228 113 18 112 222 11 49 104 242 94 136 60 185 213 60 185 213 60 185 213 220 106 158 220 106 158 220 106 158 220 106 158 220 106 110 213 220 223 251 150 113 213 40 113 112 245 7 79 107 170 146 212 125 184 223 248 73 63 84 89 56 72 171 174 109 104 143 121 75 184 26 2 204 157 117 53 143 205 207 194 7 206 73 156 116 247 101 213 110 81 66 222 151 96 181 82 196 194 96 175 26 183 69 192 80 203 13 173 218 166 246 152 189 185 7 120 251 153 15 171 158 189 62 185 62 128 226 18 145 161 15 121 116 190 14 123 63 124 156 215 39 106 41 148 201 198 2 128 181 125 89 85 219 207 228 25 85 249 219 220 123 231 64 86 229 135 47 128 74 49 236 70 43 1 128 16 172 191 55 228 128 137 91 79 87 171 79 91 230 249 13 24 248 185 145 137 121 141 179 199 85 89 171 141 3 31 170 149 136 245 33 63 66 244 200 68 29 37 157 7 68 129 153 87 106 188 62 45 21 65 105 54 120 163 122 41 187 213 206 85 0 11 9 82 189 249 170 177 146 55 19 12 100 245 217 26 138 64 17 181 103 135 136 14 3 0 17 235 239 149 92 134 115 111 216 41 20 156 97 207 52 223 122 102 28 140 91 171 87 43 129 149 177 62 185 184 171 12 156 255 80 141 244 62 228 10 124 31 149 219 113 76 227 209 71 23 56 143 118 226 184 226 234 200 163 132 152 108 180 106 144 169 181 50 90 237 22 17 198 116 220 223 43 229 21 140 86 165 212 65 172 54 103 60 132 47 142 230 16 81 13 16 130 72 8 173 231 83 114 25 206 163 147 209 26 231 214 100 125 216 249 89 143 113 224 212 103 93 128 115 89 93 231 59 127 4 93 70 235 67 14 170 64 53 8 188 89 141 211 213 150 141 53 206 67 169 51 229 56 111 217 41 107 154 49 27 39 251 252 100 54 171 62 84 11 42 203 202 134 146 167 85 122 40 165 109 41 251 226 174 67 68 13 96 135 214 72 101 47 190 46 241 58 231 151 122 19 78 165 200 57 112 103 111 13 38 78 4 157 67 166 215 131 140 222 135 188 30 62 182 87 211 248 213 176 95 146 241 72 106 160 241 41 164 88 101 54 70 132 0 160 55 112 146 109 190 45 232 96 39 214 99 134 187 220 21 46 213 15 171 139 194 65 90 61 20 141 179 254 94 201 101 56 247 194 70 215 59 60 157 203 251 196 74 49 123 29 243 227 138 43 56 39 128 201 170 39 132 214 135 92 65 181 42 191 30 210 248 143 91 178 11 139 241 82 36 85 227 143 89 41 86 185 13 243 65 121 201 131 140 119 41 142 31 69 99 35 60 213 84 135 131 148 187 92 118 87 60 144 85 49 239 73 216 152 23 67 68 111 139 198 89 127 111 200 1 19 183 93 223 119 109 206 97 119 138 230 58 66 24 185 32 18 58 39 167 90 43 1 127 178 118 23 233 125 200 193 124 161 48 31 28 209 235 28 113 134 171 195 14 49 142 80 170 206 131 225 42 128 164 117 3 149 141 84 171 205 55 32 243 70 51 142 177 57 189 210 235 65 125 36 129 221 229 102 187 43 238 111 141 200 252 7 231 91 197 232 189 73 177 53 20 246 247 202 176 254 222 189 120 17 40 38 205 31 148 19 221 241 105 0 181 187 202 188 15 89 222 3 143 241 58 99 191 80 112 42 6 142 187 2 98 156 156 194 184 7 74 136 178 145 106 149 86 55 0 108 172 106 116 115 78 2 107 166 156 118 151 203 239 138 7 187 91 186 102 121 51 192 140 103 93 27 234 247 247 130 245 247 190 117 156 156 194 21 224 233 178 177 15 185 200 230 103 231 74 248 140 69 134 48 27 41 86 105 197 130 181 162 195 185 232 193 131 148 187 92 118 87 60 176 85 103 248 116 0 4 167 101 239 126 66 127 239 91 194 213 16 192 224 65 214 15 134 137 135 217 72 181 74 23 27 151 200 28 39 229 46 151 221 21 15 110 149 156 38 9 49 212 148 189 251 9 253 189 111 37 103 205 177 7 95 159 137 78 25 16 230 13 10 166 155 148 53 234 46 87 215 26 236 245 51 121 47 68 158 239 100 171 121 114 171 185 213 60 185 213 60 185 213 60 185 213 60 185 213 60 185 213 220 106 158 220 170 123 149 190 173 147 247 3 119 97 119 136 58 54 186 100 74 167 59 6 38 213 254 8 237 51 139 112 13 116 108 140 140 177 97 115 8 245 213 28 159 178 228 213 87 95 85 223 222 196 84 128 3 95 39 57 123 63 240 97 171 134 133 5 212 172 195 196 236 149 108 0 47 48 171 247 225 19 100 72 103 113 108 108 177 99 230 255 250 207 56 196 82 130 121 249 232 22 128 148 158 1 30 109 61 203 162 154 95 140 205 186 229 150 91 212 183 55 49 175 120 34 6 220 34 219 20 198 83 214 73 102 86 147 251 114 241 252 140 5 120 51 207 51 121 149 41 0 104 127 141 13 212 240 199 104 204 213 160 187 136 48 139 174 145 63 209 114 217 243 169 1 53 151 120 154 251 176 138 254 95 252 12 45 218 198 249 200 106 213 245 221 228 3 198 247 25 245 13 245 139 172 209 135 111 79 58 231 235 36 155 173 150 0 88 66 88 0 74 172 234 209 163 144 49 188 136 26 227 143 195 35 214 136 117 55 189 96 243 22 122 117 50 224 252 123 239 147 92 59 228 235 117 220 151 177 57 64 168 48 219 197 86 36 21 23 50 88 157 155 155 83 223 248 226 203 230 3 38 250 166 211 66 21 97 204 253 91 239 79 218 126 145 209 106 180 78 50 223 160 200 170 47 173 30 142 154 252 106 122 95 174 0 128 219 110 3 0 65 177 172 1 222 217 233 127 167 191 232 136 126 19 192 194 11 218 117 248 8 218 104 0 64 21 71 76 252 79 253 101 201 181 11 207 199 63 14 84 136 197 5 224 102 60 86 133 152 247 172 215 101 251 136 64 181 144 193 42 0 245 45 125 241 101 247 6 164 64 31 192 13 237 48 90 116 11 252 47 126 191 134 157 188 148 237 88 109 48 219 42 230 142 213 200 42 252 161 72 39 92 151 175 1 171 172 178 243 172 117 250 235 83 236 69 183 212 109 2 172 76 23 214 187 241 209 54 128 31 179 208 229 252 143 59 43 22 123 29 108 2 155 202 53 219 189 25 175 171 193 233 63 29 117 25 42 169 153 173 154 23 95 230 171 9 78 105 45 58 133 73 64 44 59 134 93 255 211 216 201 87 178 89 253 96 9 42 197 20 171 250 223 128 110 0 192 83 79 241 245 126 143 110 231 182 219 228 87 253 80 178 46 30 129 204 23 99 252 242 143 18 172 176 90 139 84 30 196 117 167 190 246 0 80 111 94 199 131 55 243 227 219 252 119 240 23 137 66 174 82 66 227 87 129 95 109 160 100 106 198 3 138 149 24 133 216 253 135 180 252 66 17 222 219 255 54 209 58 237 207 42 151 218 72 210 202 22 23 237 1 230 93 255 179 232 167 209 204 100 181 81 62 5 149 123 82 173 174 171 201 235 201 253 186 116 219 110 40 150 207 122 207 23 33 83 215 55 111 10 215 239 4 128 215 73 101 174 142 238 153 119 0 245 51 93 212 231 98 220 151 252 19 228 199 56 185 53 124 198 105 183 157 207 160 230 234 82 219 0 218 74 107 202 177 90 145 82 79 22 43 234 30 56 163 85 38 181 58 93 149 90 137 105 101 82 137 146 172 6 30 162 60 73 153 172 126 176 3 21 124 209 100 149 175 159 44 131 106 129 245 235 166 159 129 123 135 16 198 59 195 55 239 133 85 0 232 221 140 207 88 184 127 66 136 137 167 96 157 209 248 145 143 91 232 117 53 126 31 218 61 122 252 113 234 181 181 197 176 139 222 185 101 0 203 231 188 98 150 99 53 250 204 201 111 214 244 219 123 15 59 209 238 246 234 128 223 169 248 64 59 166 238 2 228 110 42 84 129 11 196 181 50 169 4 36 220 168 142 138 48 222 39 179 89 45 63 10 149 106 147 91 229 90 163 235 106 181 192 250 129 211 173 186 118 255 230 231 105 135 45 232 142 7 42 114 68 123 234 109 76 45 44 76 161 61 236 196 121 21 192 159 109 161 26 227 29 120 31 139 182 250 99 30 58 177 250 167 87 101 245 202 234 233 118 210 177 202 251 111 195 143 20 197 132 140 10 192 186 34 100 70 201 216 214 254 56 91 231 84 125 211 181 70 27 207 45 249 73 203 222 86 240 137 108 86 91 80 193 151 179 188 179 41 68 86 11 67 172 31 56 221 170 125 124 107 90 204 207 11 214 12 253 177 6 198 123 15 177 149 201 201 89 158 124 242 29 239 120 114 114 217 209 120 97 242 247 240 71 95 212 214 206 62 137 40 252 243 74 203 77 138 222 151 55 151 179 28 171 210 90 64 20 140 178 53 221 97 94 228 186 92 71 152 122 153 175 115 170 190 233 207 129 85 130 210 42 165 114 77 207 101 179 122 31 84 172 94 202 58 201 172 23 130 245 205 166 88 61 62 220 36 10 2 98 105 62 179 85 38 88 172 14 81 111 121 98 98 185 71 196 248 107 248 7 205 56 175 32 150 10 197 210 152 23 243 141 253 255 110 41 46 213 141 164 242 156 217 240 0 111 227 12 13 20 17 165 192 94 7 77 129 109 14 225 100 179 90 131 202 243 105 235 36 115 171 170 111 150 111 222 234 42 123 187 52 236 236 209 101 76 98 164 76 217 179 34 2 141 4 34 22 109 120 58 160 96 58 109 201 107 158 2 91 27 216 24 103 101 84 136 209 21 135 222 172 8 41 157 193 132 39 48 42 84 152 155 66 225 128 123 33 28 250 238 73 222 11 145 39 183 154 39 183 154 39 183 154 39 183 154 91 205 147 91 205 147 91 205 147 91 205 147 91 93 152 90 136 131 220 106 11 81 138 46 101 141 11 24 39 47 184 174 121 247 118 81 164 55 49 248 40 90 38 28 134 243 210 88 145 245 63 31 40 95 156 154 90 148 156 199 29 3 186 148 41 123 116 196 218 128 109 152 30 90 237 255 192 87 209 207 143 144 41 173 171 45 67 147 1 138 21 211 242 180 182 13 106 113 225 110 237 44 204 139 159 34 225 73 118 139 166 189 85 76 216 33 104 162 153 217 234 155 191 238 241 169 175 221 115 231 107 146 243 28 65 99 114 78 130 244 254 228 189 154 209 132 128 129 133 86 69 52 246 48 250 121 152 88 220 210 24 126 229 26 52 122 202 184 86 227 179 176 37 183 241 44 233 185 223 251 41 102 21 248 195 192 5 113 116 195 112 152 117 166 126 227 13 16 11 222 248 141 169 142 209 42 253 147 169 5 94 230 214 48 58 229 253 207 233 220 178 246 51 255 51 133 195 15 207 74 206 226 2 79 244 40 166 27 183 246 163 155 90 66 63 75 153 94 5 32 192 118 93 27 24 146 117 110 160 159 27 108 231 250 255 244 87 254 192 31 130 3 182 105 48 180 112 54 173 136 91 236 176 169 224 67 95 53 88 253 35 16 5 250 91 191 246 119 88 51 225 98 241 206 229 187 171 196 82 189 123 249 206 226 162 78 75 240 65 127 238 207 255 5 140 233 101 32 83 171 232 211 101 170 124 221 227 8 27 185 119 241 162 199 120 226 186 202 222 115 244 241 111 62 214 80 92 229 132 148 212 149 54 210 59 110 86 219 17 109 175 102 235 73 36 224 248 137 19 199 251 86 205 147 74 45 0 219 74 37 214 140 188 142 48 175 243 85 119 251 89 208 142 201 83 245 243 15 243 215 22 110 145 117 255 210 109 255 232 151 174 198 249 171 120 122 181 20 21 210 203 151 86 159 198 171 218 73 181 118 110 29 244 87 255 218 95 255 27 113 76 157 90 216 199 242 233 34 17 95 151 88 174 122 135 195 26 247 198 11 0 56 199 93 65 112 151 137 131 136 205 63 134 182 67 205 23 139 0 142 145 158 53 200 52 136 183 51 241 142 27 122 119 40 220 123 55 101 178 42 200 178 96 219 176 172 33 65 212 81 147 58 241 75 85 20 110 245 149 8 191 194 255 8 122 20 235 93 250 49 121 134 86 132 248 155 71 97 176 250 67 255 234 127 109 48 238 80 89 10 217 154 85 120 54 84 84 38 7 183 104 86 239 57 86 24 167 31 10 254 238 223 211 172 158 122 195 145 160 32 49 91 247 88 174 122 135 90 156 203 213 238 132 16 208 57 170 101 162 114 155 113 243 74 184 179 184 78 68 223 47 249 172 185 103 183 254 88 166 235 42 57 111 151 240 237 78 54 171 68 195 195 22 96 13 15 203 123 224 247 170 73 239 37 21 203 77 180 122 57 194 151 227 84 30 251 81 142 159 224 150 136 254 254 55 30 102 246 92 34 106 254 195 95 51 217 254 214 231 126 6 120 66 225 39 128 159 249 220 183 136 136 89 157 155 93 42 75 208 140 227 238 147 171 37 34 250 212 231 53 171 30 34 240 200 113 120 113 126 252 17 146 129 198 149 61 157 183 5 145 168 106 188 1 180 186 83 225 62 106 24 164 86 231 183 38 2 126 93 21 50 160 120 122 27 192 70 143 184 213 237 159 49 88 149 167 95 121 18 222 249 68 6 192 206 60 35 78 146 213 238 14 239 82 66 247 212 125 6 75 244 207 255 197 47 157 141 243 127 105 29 137 138 121 134 249 191 245 203 13 33 86 20 94 17 162 241 203 191 101 178 74 159 137 26 135 125 47 70 107 239 241 65 223 250 55 159 251 183 32 226 235 21 83 169 200 215 43 46 150 40 101 29 99 141 151 136 74 58 127 18 152 122 240 131 170 243 87 147 90 8 154 138 176 235 170 150 119 1 239 210 217 81 153 31 254 225 240 27 197 18 158 126 97 219 210 234 132 216 205 132 246 112 231 54 44 101 53 237 175 44 172 8 43 162 150 148 193 44 253 251 255 240 31 173 243 241 27 247 255 116 177 118 245 37 79 94 79 248 252 79 125 227 215 159 32 45 79 252 250 55 62 101 178 218 107 67 166 54 19 163 119 97 29 244 95 254 235 127 67 157 12 13 162 139 124 189 226 8 155 57 145 145 215 42 149 154 206 31 135 28 216 20 87 198 241 184 65 170 2 41 215 85 182 74 103 234 25 56 60 253 90 128 180 154 120 94 63 132 255 190 50 178 117 182 173 89 253 237 179 245 232 42 94 63 251 219 218 135 75 67 173 22 90 164 91 130 255 169 255 249 48 46 146 150 224 67 181 175 64 2 109 190 231 211 231 127 17 223 36 45 223 196 47 126 158 124 143 89 165 229 91 101 254 119 16 131 101 81 0 253 159 217 215 182 38 20 99 235 18 15 202 79 158 52 115 124 137 156 99 146 167 74 229 251 159 119 115 239 251 30 88 205 18 56 26 47 241 154 188 206 54 207 47 11 218 188 25 59 231 39 70 175 76 78 94 25 157 56 31 127 29 93 219 26 129 101 97 100 235 90 12 11 49 39 174 220 0 176 25 144 158 31 247 94 134 4 218 252 153 26 251 188 135 76 179 30 30 145 115 66 100 252 37 18 8 211 43 77 162 183 96 221 227 83 75 246 141 56 215 164 178 247 171 236 186 42 131 170 2 41 103 108 144 16 35 142 51 34 196 16 146 103 209 138 152 83 11 25 199 227 20 139 142 169 113 116 99 120 120 131 154 124 72 62 150 172 198 248 61 240 24 140 58 179 197 4 231 19 253 206 109 202 106 213 229 172 223 255 236 213 85 223 242 193 243 118 163 113 236 121 141 143 115 169 220 146 158 76 103 108 254 27 67 54 43 91 70 205 83 87 28 103 133 246 147 57 245 152 131 119 86 51 188 49 181 65 9 235 12 143 78 148 223 68 190 60 205 251 171 203 194 36 53 101 255 23 40 115 132 250 141 161 160 255 91 14 28 208 0 0 0 32 8 219 168 98 2 250 151 179 135 158 97 70 46 21 148 168 93 177 75 161 238 199 0 0 0 0 73 69 78 68 174 66 96 130) asByteArray
]

{ #category : #private }
OHFileRequestHandler >> javaScriptResponseFor: aContentSelector [

	^self respondWith: (self perform: aContentSelector) usingMIMEType: 'text/javascript'
	
]

{ #category : #uploads }
OHFileRequestHandler >> jquery181minJs [
	^ '/*! jQuery v@1.8.1 jquery.com | jquery.org/license */
(function(a,b){function G(a){var b=F[a]={};return p.each(a.split(s),function(a,c){b[c]=!0}),b}function J(a,c,d){if(d===b&&a.nodeType===1){var e="data-"+c.replace(I,"-$1").toLowerCase();d=a.getAttribute(e);if(typeof d=="string"){try{d=d==="true"?!0:d==="false"?!1:d==="null"?null:+d+""===d?+d:H.test(d)?p.parseJSON(d):d}catch(f){}p.data(a,c,d)}else d=b}return d}function K(a){var b;for(b in a){if(b==="data"&&p.isEmptyObject(a[b]))continue;if(b!=="toJSON")return!1}return!0}function ba(){return!1}function bb(){return!0}function bh(a){return!a||!a.parentNode||a.parentNode.nodeType===11}function bi(a,b){do a=a[b];while(a&&a.nodeType!==1);return a}function bj(a,b,c){b=b||0;if(p.isFunction(b))return p.grep(a,function(a,d){var e=!!b.call(a,d,a);return e===c});if(b.nodeType)return p.grep(a,function(a,d){return a===b===c});if(typeof b=="string"){var d=p.grep(a,function(a){return a.nodeType===1});if(be.test(b))return p.filter(b,d,!c);b=p.filter(b,d)}return p.grep(a,function(a,d){return p.inArray(a,b)>=0===c})}function bk(a){var b=bl.split("|"),c=a.createDocumentFragment();if(c.createElement)while(b.length)c.createElement(b.pop());return c}function bC(a,b){return a.getElementsByTagName(b)[0]||a.appendChild(a.ownerDocument.createElement(b))}function bD(a,b){if(b.nodeType!==1||!p.hasData(a))return;var c,d,e,f=p._data(a),g=p._data(b,f),h=f.events;if(h){delete g.handle,g.events={};for(c in h)for(d=0,e=h[c].length;d<e;d++)p.event.add(b,c,h[c][d])}g.data&&(g.data=p.extend({},g.data))}function bE(a,b){var c;if(b.nodeType!==1)return;b.clearAttributes&&b.clearAttributes(),b.mergeAttributes&&b.mergeAttributes(a),c=b.nodeName.toLowerCase(),c==="object"?(b.parentNode&&(b.outerHTML=a.outerHTML),p.support.html5Clone&&a.innerHTML&&!p.trim(b.innerHTML)&&(b.innerHTML=a.innerHTML)):c==="input"&&bv.test(a.type)?(b.defaultChecked=b.checked=a.checked,b.value!==a.value&&(b.value=a.value)):c==="option"?b.selected=a.defaultSelected:c==="input"||c==="textarea"?b.defaultValue=a.defaultValue:c==="script"&&b.text!==a.text&&(b.text=a.text),b.removeAttribute(p.expando)}function bF(a){return typeof a.getElementsByTagName!="undefined"?a.getElementsByTagName("*"):typeof a.querySelectorAll!="undefined"?a.querySelectorAll("*"):[]}function bG(a){bv.test(a.type)&&(a.defaultChecked=a.checked)}function bY(a,b){if(b in a)return b;var c=b.charAt(0).toUpperCase()+b.slice(1),d=b,e=bW.length;while(e--){b=bW[e]+c;if(b in a)return b}return d}function bZ(a,b){return a=b||a,p.css(a,"display")==="none"||!p.contains(a.ownerDocument,a)}function b$(a,b){var c,d,e=[],f=0,g=a.length;for(;f<g;f++){c=a[f];if(!c.style)continue;e[f]=p._data(c,"olddisplay"),b?(!e[f]&&c.style.display==="none"&&(c.style.display=""),c.style.display===""&&bZ(c)&&(e[f]=p._data(c,"olddisplay",cc(c.nodeName)))):(d=bH(c,"display"),!e[f]&&d!=="none"&&p._data(c,"olddisplay",d))}for(f=0;f<g;f++){c=a[f];if(!c.style)continue;if(!b||c.style.display==="none"||c.style.display==="")c.style.display=b?e[f]||"":"none"}return a}function b_(a,b,c){var d=bP.exec(b);return d?Math.max(0,d[1]-(c||0))+(d[2]||"px"):b}function ca(a,b,c,d){var e=c===(d?"border":"content")?4:b==="width"?1:0,f=0;for(;e<4;e+=2)c==="margin"&&(f+=p.css(a,c+bV[e],!0)),d?(c==="content"&&(f-=parseFloat(bH(a,"padding"+bV[e]))||0),c!=="margin"&&(f-=parseFloat(bH(a,"border"+bV[e]+"Width"))||0)):(f+=parseFloat(bH(a,"padding"+bV[e]))||0,c!=="padding"&&(f+=parseFloat(bH(a,"border"+bV[e]+"Width"))||0));return f}function cb(a,b,c){var d=b==="width"?a.offsetWidth:a.offsetHeight,e=!0,f=p.support.boxSizing&&p.css(a,"boxSizing")==="border-box";if(d<=0||d==null){d=bH(a,b);if(d<0||d==null)d=a.style[b];if(bQ.test(d))return d;e=f&&(p.support.boxSizingReliable||d===a.style[b]),d=parseFloat(d)||0}return d+ca(a,b,c||(f?"border":"content"),e)+"px"}function cc(a){if(bS[a])return bS[a];var b=p("<"+a+">").appendTo(e.body),c=b.css("display");b.remove();if(c==="none"||c===""){bI=e.body.appendChild(bI||p.extend(e.createElement("iframe"),{frameBorder:0,width:0,height:0}));if(!bJ||!bI.createElement)bJ=(bI.contentWindow||bI.contentDocument).document,bJ.write("<!doctype html><html><body>"),bJ.close();b=bJ.body.appendChild(bJ.createElement(a)),c=bH(b,"display"),e.body.removeChild(bI)}return bS[a]=c,c}function ci(a,b,c,d){var e;if(p.isArray(b))p.each(b,function(b,e){c||ce.test(a)?d(a,e):ci(a+"["+(typeof e=="object"?b:"")+"]",e,c,d)});else if(!c&&p.type(b)==="object")for(e in b)ci(a+"["+e+"]",b[e],c,d);else d(a,b)}function cz(a){return function(b,c){typeof b!="string"&&(c=b,b="*");var d,e,f,g=b.toLowerCase().split(s),h=0,i=g.length;if(p.isFunction(c))for(;h<i;h++)d=g[h],f=/^\+/.test(d),f&&(d=d.substr(1)||"*"),e=a[d]=a[d]||[],e[f?"unshift":"push"](c)}}function cA(a,c,d,e,f,g){f=f||c.dataTypes[0],g=g||{},g[f]=!0;var h,i=a[f],j=0,k=i?i.length:0,l=a===cv;for(;j<k&&(l||!h);j++)h=i[j](c,d,e),typeof h=="string"&&(!l||g[h]?h=b:(c.dataTypes.unshift(h),h=cA(a,c,d,e,h,g)));return(l||!h)&&!g["*"]&&(h=cA(a,c,d,e,"*",g)),h}function cB(a,c){var d,e,f=p.ajaxSettings.flatOptions||{};for(d in c)c[d]!==b&&((f[d]?a:e||(e={}))[d]=c[d]);e&&p.extend(!0,a,e)}function cC(a,c,d){var e,f,g,h,i=a.contents,j=a.dataTypes,k=a.responseFields;for(f in k)f in d&&(c[k[f]]=d[f]);while(j[0]==="*")j.shift(),e===b&&(e=a.mimeType||c.getResponseHeader("content-type"));if(e)for(f in i)if(i[f]&&i[f].test(e)){j.unshift(f);break}if(j[0]in d)g=j[0];else{for(f in d){if(!j[0]||a.converters[f+" "+j[0]]){g=f;break}h||(h=f)}g=g||h}if(g)return g!==j[0]&&j.unshift(g),d[g]}function cD(a,b){var c,d,e,f,g=a.dataTypes.slice(),h=g[0],i={},j=0;a.dataFilter&&(b=a.dataFilter(b,a.dataType));if(g[1])for(c in a.converters)i[c.toLowerCase()]=a.converters[c];for(;e=g[++j];)if(e!=="*"){if(h!=="*"&&h!==e){c=i[h+" "+e]||i["* "+e];if(!c)for(d in i){f=d.split(" ");if(f[1]===e){c=i[h+" "+f[0]]||i["* "+f[0]];if(c){c===!0?c=i[d]:i[d]!==!0&&(e=f[0],g.splice(j--,0,e));break}}}if(c!==!0)if(c&&a["throws"])b=c(b);else try{b=c(b)}catch(k){return{state:"parsererror",error:c?k:"No conversion from "+h+" to "+e}}}h=e}return{state:"success",data:b}}function cL(){try{return new a.XMLHttpRequest}catch(b){}}function cM(){try{return new a.ActiveXObject("Microsoft.XMLHTTP")}catch(b){}}function cU(){return setTimeout(function(){cN=b},0),cN=p.now()}function cV(a,b){p.each(b,function(b,c){var d=(cT[b]||[]).concat(cT["*"]),e=0,f=d.length;for(;e<f;e++)if(d[e].call(a,b,c))return})}function cW(a,b,c){var d,e=0,f=0,g=cS.length,h=p.Deferred().always(function(){delete i.elem}),i=function(){var b=cN||cU(),c=Math.max(0,j.startTime+j.duration-b),d=1-(c/j.duration||0),e=0,f=j.tweens.length;for(;e<f;e++)j.tweens[e].run(d);return h.notifyWith(a,[j,d,c]),d<1&&f?c:(h.resolveWith(a,[j]),!1)},j=h.promise({elem:a,props:p.extend({},b),opts:p.extend(!0,{specialEasing:{}},c),originalProperties:b,originalOptions:c,startTime:cN||cU(),duration:c.duration,tweens:[],createTween:function(b,c,d){var e=p.Tween(a,j.opts,b,c,j.opts.specialEasing[b]||j.opts.easing);return j.tweens.push(e),e},stop:function(b){var c=0,d=b?j.tweens.length:0;for(;c<d;c++)j.tweens[c].run(1);return b?h.resolveWith(a,[j,b]):h.rejectWith(a,[j,b]),this}}),k=j.props;cX(k,j.opts.specialEasing);for(;e<g;e++){d=cS[e].call(j,a,k,j.opts);if(d)return d}return cV(j,k),p.isFunction(j.opts.start)&&j.opts.start.call(a,j),p.fx.timer(p.extend(i,{anim:j,queue:j.opts.queue,elem:a})),j.progress(j.opts.progress).done(j.opts.done,j.opts.complete).fail(j.opts.fail).always(j.opts.always)}function cX(a,b){var c,d,e,f,g;for(c in a){d=p.camelCase(c),e=b[d],f=a[c],p.isArray(f)&&(e=f[1],f=a[c]=f[0]),c!==d&&(a[d]=f,delete a[c]),g=p.cssHooks[d];if(g&&"expand"in g){f=g.expand(f),delete a[d];for(c in f)c in a||(a[c]=f[c],b[c]=e)}else b[d]=e}}function cY(a,b,c){var d,e,f,g,h,i,j,k,l=this,m=a.style,n={},o=[],q=a.nodeType&&bZ(a);c.queue||(j=p._queueHooks(a,"fx"),j.unqueued==null&&(j.unqueued=0,k=j.empty.fire,j.empty.fire=function(){j.unqueued||k()}),j.unqueued++,l.always(function(){l.always(function(){j.unqueued--,p.queue(a,"fx").length||j.empty.fire()})})),a.nodeType===1&&("height"in b||"width"in b)&&(c.overflow=[m.overflow,m.overflowX,m.overflowY],p.css(a,"display")==="inline"&&p.css(a,"float")==="none"&&(!p.support.inlineBlockNeedsLayout||cc(a.nodeName)==="inline"?m.display="inline-block":m.zoom=1)),c.overflow&&(m.overflow="hidden",p.support.shrinkWrapBlocks||l.done(function(){m.overflow=c.overflow[0],m.overflowX=c.overflow[1],m.overflowY=c.overflow[2]}));for(d in b){f=b[d];if(cP.exec(f)){delete b[d];if(f===(q?"hide":"show"))continue;o.push(d)}}g=o.length;if(g){h=p._data(a,"fxshow")||p._data(a,"fxshow",{}),q?p(a).show():l.done(function(){p(a).hide()}),l.done(function(){var b;p.removeData(a,"fxshow",!0);for(b in n)p.style(a,b,n[b])});for(d=0;d<g;d++)e=o[d],i=l.createTween(e,q?h[e]:0),n[e]=h[e]||p.style(a,e),e in h||(h[e]=i.start,q&&(i.end=i.start,i.start=e==="width"||e==="height"?1:0))}}function cZ(a,b,c,d,e){return new cZ.prototype.init(a,b,c,d,e)}function c$(a,b){var c,d={height:a},e=0;b=b?1:0;for(;e<4;e+=2-b)c=bV[e],d["margin"+c]=d["padding"+c]=a;return b&&(d.opacity=d.width=a),d}function da(a){return p.isWindow(a)?a:a.nodeType===9?a.defaultView||a.parentWindow:!1}var c,d,e=a.document,f=a.location,g=a.navigator,h=a.jQuery,i=a.$,j=Array.prototype.push,k=Array.prototype.slice,l=Array.prototype.indexOf,m=Object.prototype.toString,n=Object.prototype.hasOwnProperty,o=String.prototype.trim,p=function(a,b){return new p.fn.init(a,b,c)},q=/[\-+]?(?:\d*\.|)\d+(?:[eE][\-+]?\d+|)/.source,r=/\S/,s=/\s+/,t=/^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g,u=/^(?:[^#<]*(<[\w\W]+>)[^>]*$|#([\w\-]*)$)/,v=/^<(\w+)\s*\/?>(?:<\/\1>|)$/,w=/^[\],:{}\s]*$/,x=/(?:^|:|,)(?:\s*\[)+/g,y=/\\(?:["\\\/bfnrt]|u[\da-fA-F]{4})/g,z=/"[^"\\\r\n]*"|true|false|null|-?(?:\d\d*\.|)\d+(?:[eE][\-+]?\d+|)/g,A=/^-ms-/,B=/-([\da-z])/gi,C=function(a,b){return(b+"").toUpperCase()},D=function(){e.addEventListener?(e.removeEventListener("DOMContentLoaded",D,!1),p.ready()):e.readyState==="complete"&&(e.detachEvent("onreadystatechange",D),p.ready())},E={};p.fn=p.prototype={constructor:p,init:function(a,c,d){var f,g,h,i;if(!a)return this;if(a.nodeType)return this.context=this[0]=a,this.length=1,this;if(typeof a=="string"){a.charAt(0)==="<"&&a.charAt(a.length-1)===">"&&a.length>=3?f=[null,a,null]:f=u.exec(a);if(f&&(f[1]||!c)){if(f[1])return c=c instanceof p?c[0]:c,i=c&&c.nodeType?c.ownerDocument||c:e,a=p.parseHTML(f[1],i,!0),v.test(f[1])&&p.isPlainObject(c)&&this.attr.call(a,c,!0),p.merge(this,a);g=e.getElementById(f[2]);if(g&&g.parentNode){if(g.id!==f[2])return d.find(a);this.length=1,this[0]=g}return this.context=e,this.selector=a,this}return!c||c.jquery?(c||d).find(a):this.constructor(c).find(a)}return p.isFunction(a)?d.ready(a):(a.selector!==b&&(this.selector=a.selector,this.context=a.context),p.makeArray(a,this))},selector:"",jquery:"1.8.1",length:0,size:function(){return this.length},toArray:function(){return k.call(this)},get:function(a){return a==null?this.toArray():a<0?this[this.length+a]:this[a]},pushStack:function(a,b,c){var d=p.merge(this.constructor(),a);return d.prevObject=this,d.context=this.context,b==="find"?d.selector=this.selector+(this.selector?" ":"")+c:b&&(d.selector=this.selector+"."+b+"("+c+")"),d},each:function(a,b){return p.each(this,a,b)},ready:function(a){return p.ready.promise().done(a),this},eq:function(a){return a=+a,a===-1?this.slice(a):this.slice(a,a+1)},first:function(){return this.eq(0)},last:function(){return this.eq(-1)},slice:function(){return this.pushStack(k.apply(this,arguments),"slice",k.call(arguments).join(","))},map:function(a){return this.pushStack(p.map(this,function(b,c){return a.call(b,c,b)}))},end:function(){return this.prevObject||this.constructor(null)},push:j,sort:[].sort,splice:[].splice},p.fn.init.prototype=p.fn,p.extend=p.fn.extend=function(){var a,c,d,e,f,g,h=arguments[0]||{},i=1,j=arguments.length,k=!1;typeof h=="boolean"&&(k=h,h=arguments[1]||{},i=2),typeof h!="object"&&!p.isFunction(h)&&(h={}),j===i&&(h=this,--i);for(;i<j;i++)if((a=arguments[i])!=null)for(c in a){d=h[c],e=a[c];if(h===e)continue;k&&e&&(p.isPlainObject(e)||(f=p.isArray(e)))?(f?(f=!1,g=d&&p.isArray(d)?d:[]):g=d&&p.isPlainObject(d)?d:{},h[c]=p.extend(k,g,e)):e!==b&&(h[c]=e)}return h},p.extend({noConflict:function(b){return a.$===p&&(a.$=i),b&&a.jQuery===p&&(a.jQuery=h),p},isReady:!1,readyWait:1,holdReady:function(a){a?p.readyWait++:p.ready(!0)},ready:function(a){if(a===!0?--p.readyWait:p.isReady)return;if(!e.body)return setTimeout(p.ready,1);p.isReady=!0;if(a!==!0&&--p.readyWait>0)return;d.resolveWith(e,[p]),p.fn.trigger&&p(e).trigger("ready").off("ready")},isFunction:function(a){return p.type(a)==="function"},isArray:Array.isArray||function(a){return p.type(a)==="array"},isWindow:function(a){return a!=null&&a==a.window},isNumeric:function(a){return!isNaN(parseFloat(a))&&isFinite(a)},type:function(a){return a==null?String(a):E[m.call(a)]||"object"},isPlainObject:function(a){if(!a||p.type(a)!=="object"||a.nodeType||p.isWindow(a))return!1;try{if(a.constructor&&!n.call(a,"constructor")&&!n.call(a.constructor.prototype,"isPrototypeOf"))return!1}catch(c){return!1}var d;for(d in a);return d===b||n.call(a,d)},isEmptyObject:function(a){var b;for(b in a)return!1;return!0},error:function(a){throw new Error(a)},parseHTML:function(a,b,c){var d;return!a||typeof a!="string"?null:(typeof b=="boolean"&&(c=b,b=0),b=b||e,(d=v.exec(a))?[b.createElement(d[1])]:(d=p.buildFragment([a],b,c?null:[]),p.merge([],(d.cacheable?p.clone(d.fragment):d.fragment).childNodes)))},parseJSON:function(b){if(!b||typeof b!="string")return null;b=p.trim(b);if(a.JSON&&a.JSON.parse)return a.JSON.parse(b);if(w.test(b.replace(y,"@").replace(z,"]").replace(x,"")))return(new Function("return "+b))();p.error("Invalid JSON: "+b)},parseXML:function(c){var d,e;if(!c||typeof c!="string")return null;try{a.DOMParser?(e=new DOMParser,d=e.parseFromString(c,"text/xml")):(d=new ActiveXObject("Microsoft.XMLDOM"),d.async="false",d.loadXML(c))}catch(f){d=b}return(!d||!d.documentElement||d.getElementsByTagName("parsererror").length)&&p.error("Invalid XML: "+c),d},noop:function(){},globalEval:function(b){b&&r.test(b)&&(a.execScript||function(b){a.eval.call(a,b)})(b)},camelCase:function(a){return a.replace(A,"ms-").replace(B,C)},nodeName:function(a,b){return a.nodeName&&a.nodeName.toUpperCase()===b.toUpperCase()},each:function(a,c,d){var e,f=0,g=a.length,h=g===b||p.isFunction(a);if(d){if(h){for(e in a)if(c.apply(a[e],d)===!1)break}else for(;f<g;)if(c.apply(a[f++],d)===!1)break}else if(h){for(e in a)if(c.call(a[e],e,a[e])===!1)break}else for(;f<g;)if(c.call(a[f],f,a[f++])===!1)break;return a},trim:o&&!o.call("ï»¿Â ")?function(a){return a==null?"":o.call(a)}:function(a){return a==null?"":a.toString().replace(t,"")},makeArray:function(a,b){var c,d=b||[];return a!=null&&(c=p.type(a),a.length==null||c==="string"||c==="function"||c==="regexp"||p.isWindow(a)?j.call(d,a):p.merge(d,a)),d},inArray:function(a,b,c){var d;if(b){if(l)return l.call(b,a,c);d=b.length,c=c?c<0?Math.max(0,d+c):c:0;for(;c<d;c++)if(c in b&&b[c]===a)return c}return-1},merge:function(a,c){var d=c.length,e=a.length,f=0;if(typeof d=="number")for(;f<d;f++)a[e++]=c[f];else while(c[f]!==b)a[e++]=c[f++];return a.length=e,a},grep:function(a,b,c){var d,e=[],f=0,g=a.length;c=!!c;for(;f<g;f++)d=!!b(a[f],f),c!==d&&e.push(a[f]);return e},map:function(a,c,d){var e,f,g=[],h=0,i=a.length,j=a instanceof p||i!==b&&typeof i=="number"&&(i>0&&a[0]&&a[i-1]||i===0||p.isArray(a));if(j)for(;h<i;h++)e=c(a[h],h,d),e!=null&&(g[g.length]=e);else for(f in a)e=c(a[f],f,d),e!=null&&(g[g.length]=e);return g.concat.apply([],g)},guid:1,proxy:function(a,c){var d,e,f;return typeof c=="string"&&(d=a[c],c=a,a=d),p.isFunction(a)?(e=k.call(arguments,2),f=function(){return a.apply(c,e.concat(k.call(arguments)))},f.guid=a.guid=a.guid||f.guid||p.guid++,f):b},access:function(a,c,d,e,f,g,h){var i,j=d==null,k=0,l=a.length;if(d&&typeof d=="object"){for(k in d)p.access(a,c,k,d[k],1,g,e);f=1}else if(e!==b){i=h===b&&p.isFunction(e),j&&(i?(i=c,c=function(a,b,c){return i.call(p(a),c)}):(c.call(a,e),c=null));if(c)for(;k<l;k++)c(a[k],d,i?e.call(a[k],k,c(a[k],d)):e,h);f=1}return f?a:j?c.call(a):l?c(a[0],d):g},now:function(){return(new Date).getTime()}}),p.ready.promise=function(b){if(!d){d=p.Deferred();if(e.readyState==="complete")setTimeout(p.ready,1);else if(e.addEventListener)e.addEventListener("DOMContentLoaded",D,!1),a.addEventListener("load",p.ready,!1);else{e.attachEvent("onreadystatechange",D),a.attachEvent("onload",p.ready);var c=!1;try{c=a.frameElement==null&&e.documentElement}catch(f){}c&&c.doScroll&&function g(){if(!p.isReady){try{c.doScroll("left")}catch(a){return setTimeout(g,50)}p.ready()}}()}}return d.promise(b)},p.each("Boolean Number String Function Array Date RegExp Object".split(" "),function(a,b){E["[object "+b+"]"]=b.toLowerCase()}),c=p(e);var F={};p.Callbacks=function(a){a=typeof a=="string"?F[a]||G(a):p.extend({},a);var c,d,e,f,g,h,i=[],j=!a.once&&[],k=function(b){c=a.memory&&b,d=!0,h=f||0,f=0,g=i.length,e=!0;for(;i&&h<g;h++)if(i[h].apply(b[0],b[1])===!1&&a.stopOnFalse){c=!1;break}e=!1,i&&(j?j.length&&k(j.shift()):c?i=[]:l.disable())},l={add:function(){if(i){var b=i.length;(function d(b){p.each(b,function(b,c){var e=p.type(c);e==="function"&&(!a.unique||!l.has(c))?i.push(c):c&&c.length&&e!=="string"&&d(c)})})(arguments),e?g=i.length:c&&(f=b,k(c))}return this},remove:function(){return i&&p.each(arguments,function(a,b){var c;while((c=p.inArray(b,i,c))>-1)i.splice(c,1),e&&(c<=g&&g--,c<=h&&h--)}),this},has:function(a){return p.inArray(a,i)>-1},empty:function(){return i=[],this},disable:function(){return i=j=c=b,this},disabled:function(){return!i},lock:function(){return j=b,c||l.disable(),this},locked:function(){return!j},fireWith:function(a,b){return b=b||[],b=[a,b.slice?b.slice():b],i&&(!d||j)&&(e?j.push(b):k(b)),this},fire:function(){return l.fireWith(this,arguments),this},fired:function(){return!!d}};return l},p.extend({Deferred:function(a){var b=[["resolve","done",p.Callbacks("once memory"),"resolved"],["reject","fail",p.Callbacks("once memory"),"rejected"],["notify","progress",p.Callbacks("memory")]],c="pending",d={state:function(){return c},always:function(){return e.done(arguments).fail(arguments),this},then:function(){var a=arguments;return p.Deferred(function(c){p.each(b,function(b,d){var f=d[0],g=a[b];e[d[1]](p.isFunction(g)?function(){var a=g.apply(this,arguments);a&&p.isFunction(a.promise)?a.promise().done(c.resolve).fail(c.reject).progress(c.notify):c[f+"With"](this===e?c:this,[a])}:c[f])}),a=null}).promise()},promise:function(a){return typeof a=="object"?p.extend(a,d):d}},e={};return d.pipe=d.then,p.each(b,function(a,f){var g=f[2],h=f[3];d[f[1]]=g.add,h&&g.add(function(){c=h},b[a^1][2].disable,b[2][2].lock),e[f[0]]=g.fire,e[f[0]+"With"]=g.fireWith}),d.promise(e),a&&a.call(e,e),e},when:function(a){var b=0,c=k.call(arguments),d=c.length,e=d!==1||a&&p.isFunction(a.promise)?d:0,f=e===1?a:p.Deferred(),g=function(a,b,c){return function(d){b[a]=this,c[a]=arguments.length>1?k.call(arguments):d,c===h?f.notifyWith(b,c):--e||f.resolveWith(b,c)}},h,i,j;if(d>1){h=new Array(d),i=new Array(d),j=new Array(d);for(;b<d;b++)c[b]&&p.isFunction(c[b].promise)?c[b].promise().done(g(b,j,c)).fail(f.reject).progress(g(b,i,h)):--e}return e||f.resolveWith(j,c),f.promise()}}),p.support=function(){var b,c,d,f,g,h,i,j,k,l,m,n=e.createElement("div");n.setAttribute("className","t"),n.innerHTML="  <link/><table></table><a href=''/a''>a</a><input type=''checkbox''/>",c=n.getElementsByTagName("*"),d=n.getElementsByTagName("a")[0],d.style.cssText="top:1px;float:left;opacity:.5";if(!c||!c.length||!d)return{};f=e.createElement("select"),g=f.appendChild(e.createElement("option")),h=n.getElementsByTagName("input")[0],b={leadingWhitespace:n.firstChild.nodeType===3,tbody:!n.getElementsByTagName("tbody").length,htmlSerialize:!!n.getElementsByTagName("link").length,style:/top/.test(d.getAttribute("style")),hrefNormalized:d.getAttribute("href")==="/a",opacity:/^0.5/.test(d.style.opacity),cssFloat:!!d.style.cssFloat,checkOn:h.value==="on",optSelected:g.selected,getSetAttribute:n.className!=="t",enctype:!!e.createElement("form").enctype,html5Clone:e.createElement("nav").cloneNode(!0).outerHTML!=="<:nav></:nav>",boxModel:e.compatMode==="CSS1Compat",submitBubbles:!0,changeBubbles:!0,focusinBubbles:!1,deleteExpando:!0,noCloneEvent:!0,inlineBlockNeedsLayout:!1,shrinkWrapBlocks:!1,reliableMarginRight:!0,boxSizingReliable:!0,pixelPosition:!1},h.checked=!0,b.noCloneChecked=h.cloneNode(!0).checked,f.disabled=!0,b.optDisabled=!g.disabled;try{delete n.test}catch(o){b.deleteExpando=!1}!n.addEventListener&&n.attachEvent&&n.fireEvent&&(n.attachEvent("onclick",m=function(){b.noCloneEvent=!1}),n.cloneNode(!0).fireEvent("onclick"),n.detachEvent("onclick",m)),h=e.createElement("input"),h.value="t",h.setAttribute("type","radio"),b.radioValue=h.value==="t",h.setAttribute("checked","checked"),h.setAttribute("name","t"),n.appendChild(h),i=e.createDocumentFragment(),i.appendChild(n.lastChild),b.checkClone=i.cloneNode(!0).cloneNode(!0).lastChild.checked,b.appendChecked=h.checked,i.removeChild(h),i.appendChild(n);if(n.attachEvent)for(k in{submit:!0,change:!0,focusin:!0})j="on"+k,l=j in n,l||(n.setAttribute(j,"return;"),l=typeof n[j]=="function"),b[k+"Bubbles"]=l;return p(function(){var c,d,f,g,h="padding:0;margin:0;border:0;display:block;overflow:hidden;",i=e.getElementsByTagName("body")[0];if(!i)return;c=e.createElement("div"),c.style.cssText="visibility:hidden;border:0;width:0;height:0;position:static;top:0;margin-top:1px",i.insertBefore(c,i.firstChild),d=e.createElement("div"),c.appendChild(d),d.innerHTML="<table><tr><td></td><td>t</td></tr></table>",f=d.getElementsByTagName("td"),f[0].style.cssText="padding:0;margin:0;border:0;display:none",l=f[0].offsetHeight===0,f[0].style.display="",f[1].style.display="none",b.reliableHiddenOffsets=l&&f[0].offsetHeight===0,d.innerHTML="",d.style.cssText="box-sizing:border-box;-moz-box-sizing:border-box;-webkit-box-sizing:border-box;padding:1px;border:1px;display:block;width:4px;margin-top:1%;position:absolute;top:1%;",b.boxSizing=d.offsetWidth===4,b.doesNotIncludeMarginInBodyOffset=i.offsetTop!==1,a.getComputedStyle&&(b.pixelPosition=(a.getComputedStyle(d,null)||{}).top!=="1%",b.boxSizingReliable=(a.getComputedStyle(d,null)||{width:"4px"}).width==="4px",g=e.createElement("div"),g.style.cssText=d.style.cssText=h,g.style.marginRight=g.style.width="0",d.style.width="1px",d.appendChild(g),b.reliableMarginRight=!parseFloat((a.getComputedStyle(g,null)||{}).marginRight)),typeof d.style.zoom!="undefined"&&(d.innerHTML="",d.style.cssText=h+"width:1px;padding:1px;display:inline;zoom:1",b.inlineBlockNeedsLayout=d.offsetWidth===3,d.style.display="block",d.style.overflow="visible",d.innerHTML="<div></div>",d.firstChild.style.width="5px",b.shrinkWrapBlocks=d.offsetWidth!==3,c.style.zoom=1),i.removeChild(c),c=d=f=g=null}),i.removeChild(n),c=d=f=g=h=i=n=null,b}();var H=/(?:\{[\s\S]*\}|\[[\s\S]*\])$/,I=/([A-Z])/g;p.extend({cache:{},deletedIds:[],uuid:0,expando:"jQuery"+(p.fn.jquery+Math.random()).replace(/\D/g,""),noData:{embed:!0,object:"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000",applet:!0},hasData:function(a){return a=a.nodeType?p.cache[a[p.expando]]:a[p.expando],!!a&&!K(a)},data:function(a,c,d,e){if(!p.acceptData(a))return;var f,g,h=p.expando,i=typeof c=="string",j=a.nodeType,k=j?p.cache:a,l=j?a[h]:a[h]&&h;if((!l||!k[l]||!e&&!k[l].data)&&i&&d===b)return;l||(j?a[h]=l=p.deletedIds.pop()||++p.uuid:l=h),k[l]||(k[l]={},j||(k[l].toJSON=p.noop));if(typeof c=="object"||typeof c=="function")e?k[l]=p.extend(k[l],c):k[l].data=p.extend(k[l].data,c);return f=k[l],e||(f.data||(f.data={}),f=f.data),d!==b&&(f[p.camelCase(c)]=d),i?(g=f[c],g==null&&(g=f[p.camelCase(c)])):g=f,g},removeData:function(a,b,c){if(!p.acceptData(a))return;var d,e,f,g=a.nodeType,h=g?p.cache:a,i=g?a[p.expando]:p.expando;if(!h[i])return;if(b){d=c?h[i]:h[i].data;if(d){p.isArray(b)||(b in d?b=[b]:(b=p.camelCase(b),b in d?b=[b]:b=b.split(" ")));for(e=0,f=b.length;e<f;e++)delete d[b[e]];if(!(c?K:p.isEmptyObject)(d))return}}if(!c){delete h[i].data;if(!K(h[i]))return}g?p.cleanData([a],!0):p.support.deleteExpando||h!=h.window?delete h[i]:h[i]=null},_data:function(a,b,c){return p.data(a,b,c,!0)},acceptData:function(a){var b=a.nodeName&&p.noData[a.nodeName.toLowerCase()];return!b||b!==!0&&a.getAttribute("classid")===b}}),p.fn.extend({data:function(a,c){var d,e,f,g,h,i=this[0],j=0,k=null;if(a===b){if(this.length){k=p.data(i);if(i.nodeType===1&&!p._data(i,"parsedAttrs")){f=i.attributes;for(h=f.length;j<h;j++)g=f[j].name,g.indexOf("data-")===0&&(g=p.camelCase(g.substring(5)),J(i,g,k[g]));p._data(i,"parsedAttrs",!0)}}return k}return typeof a=="object"?this.each(function(){p.data(this,a)}):(d=a.split(".",2),d[1]=d[1]?"."+d[1]:"",e=d[1]+"!",p.access(this,function(c){if(c===b)return k=this.triggerHandler("getData"+e,[d[0]]),k===b&&i&&(k=p.data(i,a),k=J(i,a,k)),k===b&&d[1]?this.data(d[0]):k;d[1]=c,this.each(function(){var b=p(this);b.triggerHandler("setData"+e,d),p.data(this,a,c),b.triggerHandler("changeData"+e,d)})},null,c,arguments.length>1,null,!1))},removeData:function(a){return this.each(function(){p.removeData(this,a)})}}),p.extend({queue:function(a,b,c){var d;if(a)return b=(b||"fx")+"queue",d=p._data(a,b),c&&(!d||p.isArray(c)?d=p._data(a,b,p.makeArray(c)):d.push(c)),d||[]},dequeue:function(a,b){b=b||"fx";var c=p.queue(a,b),d=c.length,e=c.shift(),f=p._queueHooks(a,b),g=function(){p.dequeue(a,b)};e==="inprogress"&&(e=c.shift(),d--),e&&(b==="fx"&&c.unshift("inprogress"),delete f.stop,e.call(a,g,f)),!d&&f&&f.empty.fire()},_queueHooks:function(a,b){var c=b+"queueHooks";return p._data(a,c)||p._data(a,c,{empty:p.Callbacks("once memory").add(function(){p.removeData(a,b+"queue",!0),p.removeData(a,c,!0)})})}}),p.fn.extend({queue:function(a,c){var d=2;return typeof a!="string"&&(c=a,a="fx",d--),arguments.length<d?p.queue(this[0],a):c===b?this:this.each(function(){var b=p.queue(this,a,c);p._queueHooks(this,a),a==="fx"&&b[0]!=="inprogress"&&p.dequeue(this,a)})},dequeue:function(a){return this.each(function(){p.dequeue(this,a)})},delay:function(a,b){return a=p.fx?p.fx.speeds[a]||a:a,b=b||"fx",this.queue(b,function(b,c){var d=setTimeout(b,a);c.stop=function(){clearTimeout(d)}})},clearQueue:function(a){return this.queue(a||"fx",[])},promise:function(a,c){var d,e=1,f=p.Deferred(),g=this,h=this.length,i=function(){--e||f.resolveWith(g,[g])};typeof a!="string"&&(c=a,a=b),a=a||"fx";while(h--)d=p._data(g[h],a+"queueHooks"),d&&d.empty&&(e++,d.empty.add(i));return i(),f.promise(c)}});var L,M,N,O=/[\t\r\n]/g,P=/\r/g,Q=/^(?:button|input)$/i,R=/^(?:button|input|object|select|textarea)$/i,S=/^a(?:rea|)$/i,T=/^(?:autofocus|autoplay|async|checked|controls|defer|disabled|hidden|loop|multiple|open|readonly|required|scoped|selected)$/i,U=p.support.getSetAttribute;p.fn.extend({attr:function(a,b){return p.access(this,p.attr,a,b,arguments.length>1)},removeAttr:function(a){return this.each(function(){p.removeAttr(this,a)})},prop:function(a,b){return p.access(this,p.prop,a,b,arguments.length>1)},removeProp:function(a){return a=p.propFix[a]||a,this.each(function(){try{this[a]=b,delete this[a]}catch(c){}})},addClass:function(a){var b,c,d,e,f,g,h;if(p.isFunction(a))return this.each(function(b){p(this).addClass(a.call(this,b,this.className))});if(a&&typeof a=="string"){b=a.split(s);for(c=0,d=this.length;c<d;c++){e=this[c];if(e.nodeType===1)if(!e.className&&b.length===1)e.className=a;else{f=" "+e.className+" ";for(g=0,h=b.length;g<h;g++)~f.indexOf(" "+b[g]+" ")||(f+=b[g]+" ");e.className=p.trim(f)}}}return this},removeClass:function(a){var c,d,e,f,g,h,i;if(p.isFunction(a))return this.each(function(b){p(this).removeClass(a.call(this,b,this.className))});if(a&&typeof a=="string"||a===b){c=(a||"").split(s);for(h=0,i=this.length;h<i;h++){e=this[h];if(e.nodeType===1&&e.className){d=(" "+e.className+" ").replace(O," ");for(f=0,g=c.length;f<g;f++)while(d.indexOf(" "+c[f]+" ")>-1)d=d.replace(" "+c[f]+" "," ");e.className=a?p.trim(d):""}}}return this},toggleClass:function(a,b){var c=typeof a,d=typeof b=="boolean";return p.isFunction(a)?this.each(function(c){p(this).toggleClass(a.call(this,c,this.className,b),b)}):this.each(function(){if(c==="string"){var e,f=0,g=p(this),h=b,i=a.split(s);while(e=i[f++])h=d?h:!g.hasClass(e),g[h?"addClass":"removeClass"](e)}else if(c==="undefined"||c==="boolean")this.className&&p._data(this,"__className__",this.className),this.className=this.className||a===!1?"":p._data(this,"__className__")||""})},hasClass:function(a){var b=" "+a+" ",c=0,d=this.length;for(;c<d;c++)if(this[c].nodeType===1&&(" "+this[c].className+" ").replace(O," ").indexOf(b)>-1)return!0;return!1},val:function(a){var c,d,e,f=this[0];if(!arguments.length){if(f)return c=p.valHooks[f.type]||p.valHooks[f.nodeName.toLowerCase()],c&&"get"in c&&(d=c.get(f,"value"))!==b?d:(d=f.value,typeof d=="string"?d.replace(P,""):d==null?"":d);return}return e=p.isFunction(a),this.each(function(d){var f,g=p(this);if(this.nodeType!==1)return;e?f=a.call(this,d,g.val()):f=a,f==null?f="":typeof f=="number"?f+="":p.isArray(f)&&(f=p.map(f,function(a){return a==null?"":a+""})),c=p.valHooks[this.type]||p.valHooks[this.nodeName.toLowerCase()];if(!c||!("set"in c)||c.set(this,f,"value")===b)this.value=f})}}),p.extend({valHooks:{option:{get:function(a){var b=a.attributes.value;return!b||b.specified?a.value:a.text}},select:{get:function(a){var b,c,d,e,f=a.selectedIndex,g=[],h=a.options,i=a.type==="select-one";if(f<0)return null;c=i?f:0,d=i?f+1:h.length;for(;c<d;c++){e=h[c];if(e.selected&&(p.support.optDisabled?!e.disabled:e.getAttribute("disabled")===null)&&(!e.parentNode.disabled||!p.nodeName(e.parentNode,"optgroup"))){b=p(e).val();if(i)return b;g.push(b)}}return i&&!g.length&&h.length?p(h[f]).val():g},set:function(a,b){var c=p.makeArray(b);return p(a).find("option").each(function(){this.selected=p.inArray(p(this).val(),c)>=0}),c.length||(a.selectedIndex=-1),c}}},attrFn:{},attr:function(a,c,d,e){var f,g,h,i=a.nodeType;if(!a||i===3||i===8||i===2)return;if(e&&p.isFunction(p.fn[c]))return p(a)[c](d);if(typeof a.getAttribute=="undefined")return p.prop(a,c,d);h=i!==1||!p.isXMLDoc(a),h&&(c=c.toLowerCase(),g=p.attrHooks[c]||(T.test(c)?M:L));if(d!==b){if(d===null){p.removeAttr(a,c);return}return g&&"set"in g&&h&&(f=g.set(a,d,c))!==b?f:(a.setAttribute(c,""+d),d)}return g&&"get"in g&&h&&(f=g.get(a,c))!==null?f:(f=a.getAttribute(c),f===null?b:f)},removeAttr:function(a,b){var c,d,e,f,g=0;if(b&&a.nodeType===1){d=b.split(s);for(;g<d.length;g++)e=d[g],e&&(c=p.propFix[e]||e,f=T.test(e),f||p.attr(a,e,""),a.removeAttribute(U?e:c),f&&c in a&&(a[c]=!1))}},attrHooks:{type:{set:function(a,b){if(Q.test(a.nodeName)&&a.parentNode)p.error("type property can''t be changed");else if(!p.support.radioValue&&b==="radio"&&p.nodeName(a,"input")){var c=a.value;return a.setAttribute("type",b),c&&(a.value=c),b}}},value:{get:function(a,b){return L&&p.nodeName(a,"button")?L.get(a,b):b in a?a.value:null},set:function(a,b,c){if(L&&p.nodeName(a,"button"))return L.set(a,b,c);a.value=b}}},propFix:{tabindex:"tabIndex",readonly:"readOnly","for":"htmlFor","class":"className",maxlength:"maxLength",cellspacing:"cellSpacing",cellpadding:"cellPadding",rowspan:"rowSpan",colspan:"colSpan",usemap:"useMap",frameborder:"frameBorder",contenteditable:"contentEditable"},prop:function(a,c,d){var e,f,g,h=a.nodeType;if(!a||h===3||h===8||h===2)return;return g=h!==1||!p.isXMLDoc(a),g&&(c=p.propFix[c]||c,f=p.propHooks[c]),d!==b?f&&"set"in f&&(e=f.set(a,d,c))!==b?e:a[c]=d:f&&"get"in f&&(e=f.get(a,c))!==null?e:a[c]},propHooks:{tabIndex:{get:function(a){var c=a.getAttributeNode("tabindex");return c&&c.specified?parseInt(c.value,10):R.test(a.nodeName)||S.test(a.nodeName)&&a.href?0:b}}}}),M={get:function(a,c){var d,e=p.prop(a,c);return e===!0||typeof e!="boolean"&&(d=a.getAttributeNode(c))&&d.nodeValue!==!1?c.toLowerCase():b},set:function(a,b,c){var d;return b===!1?p.removeAttr(a,c):(d=p.propFix[c]||c,d in a&&(a[d]=!0),a.setAttribute(c,c.toLowerCase())),c}},U||(N={name:!0,id:!0,coords:!0},L=p.valHooks.button={get:function(a,c){var d;return d=a.getAttributeNode(c),d&&(N[c]?d.value!=="":d.specified)?d.value:b},set:function(a,b,c){var d=a.getAttributeNode(c);return d||(d=e.createAttribute(c),a.setAttributeNode(d)),d.value=b+""}},p.each(["width","height"],function(a,b){p.attrHooks[b]=p.extend(p.attrHooks[b],{set:function(a,c){if(c==="")return a.setAttribute(b,"auto"),c}})}),p.attrHooks.contenteditable={get:L.get,set:function(a,b,c){b===""&&(b="false"),L.set(a,b,c)}}),p.support.hrefNormalized||p.each(["href","src","width","height"],function(a,c){p.attrHooks[c]=p.extend(p.attrHooks[c],{get:function(a){var d=a.getAttribute(c,2);return d===null?b:d}})}),p.support.style||(p.attrHooks.style={get:function(a){return a.style.cssText.toLowerCase()||b},set:function(a,b){return a.style.cssText=""+b}}),p.support.optSelected||(p.propHooks.selected=p.extend(p.propHooks.selected,{get:function(a){var b=a.parentNode;return b&&(b.selectedIndex,b.parentNode&&b.parentNode.selectedIndex),null}})),p.support.enctype||(p.propFix.enctype="encoding"),p.support.checkOn||p.each(["radio","checkbox"],function(){p.valHooks[this]={get:function(a){return a.getAttribute("value")===null?"on":a.value}}}),p.each(["radio","checkbox"],function(){p.valHooks[this]=p.extend(p.valHooks[this],{set:function(a,b){if(p.isArray(b))return a.checked=p.inArray(p(a).val(),b)>=0}})});var V=/^(?:textarea|input|select)$/i,W=/^([^\.]*|)(?:\.(.+)|)$/,X=/(?:^|\s)hover(\.\S+|)\b/,Y=/^key/,Z=/^(?:mouse|contextmenu)|click/,$=/^(?:focusinfocus|focusoutblur)$/,_=function(a){return p.event.special.hover?a:a.replace(X,"mouseenter$1 mouseleave$1")};p.event={add:function(a,c,d,e,f){var g,h,i,j,k,l,m,n,o,q,r;if(a.nodeType===3||a.nodeType===8||!c||!d||!(g=p._data(a)))return;d.handler&&(o=d,d=o.handler,f=o.selector),d.guid||(d.guid=p.guid++),i=g.events,i||(g.events=i={}),h=g.handle,h||(g.handle=h=function(a){return typeof p!="undefined"&&(!a||p.event.triggered!==a.type)?p.event.dispatch.apply(h.elem,arguments):b},h.elem=a),c=p.trim(_(c)).split(" ");for(j=0;j<c.length;j++){k=W.exec(c[j])||[],l=k[1],m=(k[2]||"").split(".").sort(),r=p.event.special[l]||{},l=(f?r.delegateType:r.bindType)||l,r=p.event.special[l]||{},n=p.extend({type:l,origType:k[1],data:e,handler:d,guid:d.guid,selector:f,namespace:m.join(".")},o),q=i[l];if(!q){q=i[l]=[],q.delegateCount=0;if(!r.setup||r.setup.call(a,e,m,h)===!1)a.addEventListener?a.addEventListener(l,h,!1):a.attachEvent&&a.attachEvent("on"+l,h)}r.add&&(r.add.call(a,n),n.handler.guid||(n.handler.guid=d.guid)),f?q.splice(q.delegateCount++,0,n):q.push(n),p.event.global[l]=!0}a=null},global:{},remove:function(a,b,c,d,e){var f,g,h,i,j,k,l,m,n,o,q,r=p.hasData(a)&&p._data(a);if(!r||!(m=r.events))return;b=p.trim(_(b||"")).split(" ");for(f=0;f<b.length;f++){g=W.exec(b[f])||[],h=i=g[1],j=g[2];if(!h){for(h in m)p.event.remove(a,h+b[f],c,d,!0);continue}n=p.event.special[h]||{},h=(d?n.delegateType:n.bindType)||h,o=m[h]||[],k=o.length,j=j?new RegExp("(^|\\.)"+j.split(".").sort().join("\\.(?:.*\\.|)")+"(\\.|$)"):null;for(l=0;l<o.length;l++)q=o[l],(e||i===q.origType)&&(!c||c.guid===q.guid)&&(!j||j.test(q.namespace))&&(!d||d===q.selector||d==="**"&&q.selector)&&(o.splice(l--,1),q.selector&&o.delegateCount--,n.remove&&n.remove.call(a,q));o.length===0&&k!==o.length&&((!n.teardown||n.teardown.call(a,j,r.handle)===!1)&&p.removeEvent(a,h,r.handle),delete m[h])}p.isEmptyObject(m)&&(delete r.handle,p.removeData(a,"events",!0))},customEvent:{getData:!0,setData:!0,changeData:!0},trigger:function(c,d,f,g){if(!f||f.nodeType!==3&&f.nodeType!==8){var h,i,j,k,l,m,n,o,q,r,s=c.type||c,t=[];if($.test(s+p.event.triggered))return;s.indexOf("!")>=0&&(s=s.slice(0,-1),i=!0),s.indexOf(".")>=0&&(t=s.split("."),s=t.shift(),t.sort());if((!f||p.event.customEvent[s])&&!p.event.global[s])return;c=typeof c=="object"?c[p.expando]?c:new p.Event(s,c):new p.Event(s),c.type=s,c.isTrigger=!0,c.exclusive=i,c.namespace=t.join("."),c.namespace_re=c.namespace?new RegExp("(^|\\.)"+t.join("\\.(?:.*\\.|)")+"(\\.|$)"):null,m=s.indexOf(":")<0?"on"+s:"";if(!f){h=p.cache;for(j in h)h[j].events&&h[j].events[s]&&p.event.trigger(c,d,h[j].handle.elem,!0);return}c.result=b,c.target||(c.target=f),d=d!=null?p.makeArray(d):[],d.unshift(c),n=p.event.special[s]||{};if(n.trigger&&n.trigger.apply(f,d)===!1)return;q=[[f,n.bindType||s]];if(!g&&!n.noBubble&&!p.isWindow(f)){r=n.delegateType||s,k=$.test(r+s)?f:f.parentNode;for(l=f;k;k=k.parentNode)q.push([k,r]),l=k;l===(f.ownerDocument||e)&&q.push([l.defaultView||l.parentWindow||a,r])}for(j=0;j<q.length&&!c.isPropagationStopped();j++)k=q[j][0],c.type=q[j][1],o=(p._data(k,"events")||{})[c.type]&&p._data(k,"handle"),o&&o.apply(k,d),o=m&&k[m],o&&p.acceptData(k)&&o.apply(k,d)===!1&&c.preventDefault();return c.type=s,!g&&!c.isDefaultPrevented()&&(!n._default||n._default.apply(f.ownerDocument,d)===!1)&&(s!=="click"||!p.nodeName(f,"a"))&&p.acceptData(f)&&m&&f[s]&&(s!=="focus"&&s!=="blur"||c.target.offsetWidth!==0)&&!p.isWindow(f)&&(l=f[m],l&&(f[m]=null),p.event.triggered=s,f[s](),p.event.triggered=b,l&&(f[m]=l)),c.result}return},dispatch:function(c){c=p.event.fix(c||a.event);var d,e,f,g,h,i,j,k,l,m,n=(p._data(this,"events")||{})[c.type]||[],o=n.delegateCount,q=[].slice.call(arguments),r=!c.exclusive&&!c.namespace,s=p.event.special[c.type]||{},t=[];q[0]=c,c.delegateTarget=this;if(s.preDispatch&&s.preDispatch.call(this,c)===!1)return;if(o&&(!c.button||c.type!=="click"))for(f=c.target;f!=this;f=f.parentNode||this)if(f.disabled!==!0||c.type!=="click"){h={},j=[];for(d=0;d<o;d++)k=n[d],l=k.selector,h[l]===b&&(h[l]=p(l,this).index(f)>=0),h[l]&&j.push(k);j.length&&t.push({elem:f,matches:j})}n.length>o&&t.push({elem:this,matches:n.slice(o)});for(d=0;d<t.length&&!c.isPropagationStopped();d++){i=t[d],c.currentTarget=i.elem;for(e=0;e<i.matches.length&&!c.isImmediatePropagationStopped();e++){k=i.matches[e];if(r||!c.namespace&&!k.namespace||c.namespace_re&&c.namespace_re.test(k.namespace))c.data=k.data,c.handleObj=k,g=((p.event.special[k.origType]||{}).handle||k.handler).apply(i.elem,q),g!==b&&(c.result=g,g===!1&&(c.preventDefault(),c.stopPropagation()))}}return s.postDispatch&&s.postDispatch.call(this,c),c.result},props:"attrChange attrName relatedNode srcElement altKey bubbles cancelable ctrlKey currentTarget eventPhase metaKey relatedTarget shiftKey target timeStamp view which".split(" "),fixHooks:{},keyHooks:{props:"char charCode key keyCode".split(" "),filter:function(a,b){return a.which==null&&(a.which=b.charCode!=null?b.charCode:b.keyCode),a}},mouseHooks:{props:"button buttons clientX clientY fromElement offsetX offsetY pageX pageY screenX screenY toElement".split(" "),filter:function(a,c){var d,f,g,h=c.button,i=c.fromElement;return a.pageX==null&&c.clientX!=null&&(d=a.target.ownerDocument||e,f=d.documentElement,g=d.body,a.pageX=c.clientX+(f&&f.scrollLeft||g&&g.scrollLeft||0)-(f&&f.clientLeft||g&&g.clientLeft||0),a.pageY=c.clientY+(f&&f.scrollTop||g&&g.scrollTop||0)-(f&&f.clientTop||g&&g.clientTop||0)),!a.relatedTarget&&i&&(a.relatedTarget=i===a.target?c.toElement:i),!a.which&&h!==b&&(a.which=h&1?1:h&2?3:h&4?2:0),a}},fix:function(a){if(a[p.expando])return a;var b,c,d=a,f=p.event.fixHooks[a.type]||{},g=f.props?this.props.concat(f.props):this.props;a=p.Event(d);for(b=g.length;b;)c=g[--b],a[c]=d[c];return a.target||(a.target=d.srcElement||e),a.target.nodeType===3&&(a.target=a.target.parentNode),a.metaKey=!!a.metaKey,f.filter?f.filter(a,d):a},special:{load:{noBubble:!0},focus:{delegateType:"focusin"},blur:{delegateType:"focusout"},beforeunload:{setup:function(a,b,c){p.isWindow(this)&&(this.onbeforeunload=c)},teardown:function(a,b){this.onbeforeunload===b&&(this.onbeforeunload=null)}}},simulate:function(a,b,c,d){var e=p.extend(new p.Event,c,{type:a,isSimulated:!0,originalEvent:{}});d?p.event.trigger(e,null,b):p.event.dispatch.call(b,e),e.isDefaultPrevented()&&c.preventDefault()}},p.event.handle=p.event.dispatch,p.removeEvent=e.removeEventListener?function(a,b,c){a.removeEventListener&&a.removeEventListener(b,c,!1)}:function(a,b,c){var d="on"+b;a.detachEvent&&(typeof a[d]=="undefined"&&(a[d]=null),a.detachEvent(d,c))},p.Event=function(a,b){if(this instanceof p.Event)a&&a.type?(this.originalEvent=a,this.type=a.type,this.isDefaultPrevented=a.defaultPrevented||a.returnValue===!1||a.getPreventDefault&&a.getPreventDefault()?bb:ba):this.type=a,b&&p.extend(this,b),this.timeStamp=a&&a.timeStamp||p.now(),this[p.expando]=!0;else return new p.Event(a,b)},p.Event.prototype={preventDefault:function(){this.isDefaultPrevented=bb;var a=this.originalEvent;if(!a)return;a.preventDefault?a.preventDefault():a.returnValue=!1},stopPropagation:function(){this.isPropagationStopped=bb;var a=this.originalEvent;if(!a)return;a.stopPropagation&&a.stopPropagation(),a.cancelBubble=!0},stopImmediatePropagation:function(){this.isImmediatePropagationStopped=bb,this.stopPropagation()},isDefaultPrevented:ba,isPropagationStopped:ba,isImmediatePropagationStopped:ba},p.each({mouseenter:"mouseover",mouseleave:"mouseout"},function(a,b){p.event.special[a]={delegateType:b,bindType:b,handle:function(a){var c,d=this,e=a.relatedTarget,f=a.handleObj,g=f.selector;if(!e||e!==d&&!p.contains(d,e))a.type=f.origType,c=f.handler.apply(this,arguments),a.type=b;return c}}}),p.support.submitBubbles||(p.event.special.submit={setup:function(){if(p.nodeName(this,"form"))return!1;p.event.add(this,"click._submit keypress._submit",function(a){var c=a.target,d=p.nodeName(c,"input")||p.nodeName(c,"button")?c.form:b;d&&!p._data(d,"_submit_attached")&&(p.event.add(d,"submit._submit",function(a){a._submit_bubble=!0}),p._data(d,"_submit_attached",!0))})},postDispatch:function(a){a._submit_bubble&&(delete a._submit_bubble,this.parentNode&&!a.isTrigger&&p.event.simulate("submit",this.parentNode,a,!0))},teardown:function(){if(p.nodeName(this,"form"))return!1;p.event.remove(this,"._submit")}}),p.support.changeBubbles||(p.event.special.change={setup:function(){if(V.test(this.nodeName)){if(this.type==="checkbox"||this.type==="radio")p.event.add(this,"propertychange._change",function(a){a.originalEvent.propertyName==="checked"&&(this._just_changed=!0)}),p.event.add(this,"click._change",function(a){this._just_changed&&!a.isTrigger&&(this._just_changed=!1),p.event.simulate("change",this,a,!0)});return!1}p.event.add(this,"beforeactivate._change",function(a){var b=a.target;V.test(b.nodeName)&&!p._data(b,"_change_attached")&&(p.event.add(b,"change._change",function(a){this.parentNode&&!a.isSimulated&&!a.isTrigger&&p.event.simulate("change",this.parentNode,a,!0)}),p._data(b,"_change_attached",!0))})},handle:function(a){var b=a.target;if(this!==b||a.isSimulated||a.isTrigger||b.type!=="radio"&&b.type!=="checkbox")return a.handleObj.handler.apply(this,arguments)},teardown:function(){return p.event.remove(this,"._change"),!V.test(this.nodeName)}}),p.support.focusinBubbles||p.each({focus:"focusin",blur:"focusout"},function(a,b){var c=0,d=function(a){p.event.simulate(b,a.target,p.event.fix(a),!0)};p.event.special[b]={setup:function(){c++===0&&e.addEventListener(a,d,!0)},teardown:function(){--c===0&&e.removeEventListener(a,d,!0)}}}),p.fn.extend({on:function(a,c,d,e,f){var g,h;if(typeof a=="object"){typeof c!="string"&&(d=d||c,c=b);for(h in a)this.on(h,c,d,a[h],f);return this}d==null&&e==null?(e=c,d=c=b):e==null&&(typeof c=="string"?(e=d,d=b):(e=d,d=c,c=b));if(e===!1)e=ba;else if(!e)return this;return f===1&&(g=e,e=function(a){return p().off(a),g.apply(this,arguments)},e.guid=g.guid||(g.guid=p.guid++)),this.each(function(){p.event.add(this,a,e,d,c)})},one:function(a,b,c,d){return this.on(a,b,c,d,1)},off:function(a,c,d){var e,f;if(a&&a.preventDefault&&a.handleObj)return e=a.handleObj,p(a.delegateTarget).off(e.namespace?e.origType+"."+e.namespace:e.origType,e.selector,e.handler),this;if(typeof a=="object"){for(f in a)this.off(f,c,a[f]);return this}if(c===!1||typeof c=="function")d=c,c=b;return d===!1&&(d=ba),this.each(function(){p.event.remove(this,a,d,c)})},bind:function(a,b,c){return this.on(a,null,b,c)},unbind:function(a,b){return this.off(a,null,b)},live:function(a,b,c){return p(this.context).on(a,this.selector,b,c),this},die:function(a,b){return p(this.context).off(a,this.selector||"**",b),this},delegate:function(a,b,c,d){return this.on(b,a,c,d)},undelegate:function(a,b,c){return arguments.length==1?this.off(a,"**"):this.off(b,a||"**",c)},trigger:function(a,b){return this.each(function(){p.event.trigger(a,b,this)})},triggerHandler:function(a,b){if(this[0])return p.event.trigger(a,b,this[0],!0)},toggle:function(a){var b=arguments,c=a.guid||p.guid++,d=0,e=function(c){var e=(p._data(this,"lastToggle"+a.guid)||0)%d;return p._data(this,"lastToggle"+a.guid,e+1),c.preventDefault(),b[e].apply(this,arguments)||!1};e.guid=c;while(d<b.length)b[d++].guid=c;return this.click(e)},hover:function(a,b){return this.mouseenter(a).mouseleave(b||a)}}),p.each("blur focus focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select submit keydown keypress keyup error contextmenu".split(" "),function(a,b){p.fn[b]=function(a,c){return c==null&&(c=a,a=null),arguments.length>0?this.on(b,null,a,c):this.trigger(b)},Y.test(b)&&(p.event.fixHooks[b]=p.event.keyHooks),Z.test(b)&&(p.event.fixHooks[b]=p.event.mouseHooks)}),function(a,b){function $(a,b,c,d){c=c||[],b=b||q;var e,f,g,j,k=b.nodeType;if(k!==1&&k!==9)return[];if(!a||typeof a!="string")return c;g=h(b);if(!g&&!d)if(e=L.exec(a))if(j=e[1]){if(k===9){f=b.getElementById(j);if(!f||!f.parentNode)return c;if(f.id===j)return c.push(f),c}else if(b.ownerDocument&&(f=b.ownerDocument.getElementById(j))&&i(b,f)&&f.id===j)return c.push(f),c}else{if(e[2])return u.apply(c,t.call(b.getElementsByTagName(a),0)),c;if((j=e[3])&&X&&b.getElementsByClassName)return u.apply(c,t.call(b.getElementsByClassName(j),0)),c}return bk(a,b,c,d,g)}function _(a){return function(b){var c=b.nodeName.toLowerCase();return c==="input"&&b.type===a}}function ba(a){return function(b){var c=b.nodeName.toLowerCase();return(c==="input"||c==="button")&&b.type===a}}function bb(a,b,c){if(a===b)return c;var d=a.nextSibling;while(d){if(d===b)return-1;d=d.nextSibling}return 1}function bc(a,b,c,d){var e,g,h,i,j,k,l,m,n,p,r=!c&&b!==q,s=(r?"<s>":"")+a.replace(H,"$1<s>"),u=y[o][s];if(u)return d?0:t.call(u,0);j=a,k=[],m=0,n=f.preFilter,p=f.filter;while(j){if(!e||(g=I.exec(j)))g&&(j=j.slice(g[0].length),h.selector=l),k.push(h=[]),l="",r&&(j=" "+j);e=!1;if(g=J.exec(j))l+=g[0],j=j.slice(g[0].length),e=h.push({part:g.pop().replace(H," "),string:g[0],captures:g});for(i in p)(g=S[i].exec(j))&&(!n[i]||(g=n[i](g,b,c)))&&(l+=g[0],j=j.slice(g[0].length),e=h.push({part:i,string:g.shift(),captures:g}));if(!e)break}return l&&(h.selector=l),d?j.length:j?$.error(a):t.call(y(s,k),0)}function bd(a,b,e,f){var g=b.dir,h=s++;return a||(a=function(a){return a===e}),b.first?function(b){while(b=b[g])if(b.nodeType===1)return a(b)&&b}:f?function(b){while(b=b[g])if(b.nodeType===1&&a(b))return b}:function(b){var e,f=h+"."+c,i=f+"."+d;while(b=b[g])if(b.nodeType===1){if((e=b[o])===i)return b.sizset;if(typeof e=="string"&&e.indexOf(f)===0){if(b.sizset)return b}else{b[o]=i;if(a(b))return b.sizset=!0,b;b.sizset=!1}}}}function be(a,b){return a?function(c){var d=b(c);return d&&a(d===!0?c:d)}:b}function bf(a,b,c){var d,e,g=0;for(;d=a[g];g++)f.relative[d.part]?e=bd(e,f.relative[d.part],b,c):e=be(e,f.filter[d.part].apply(null,d.captures.concat(b,c)));return e}function bg(a){return function(b){var c,d=0;for(;c=a[d];d++)if(c(b))return!0;return!1}}function bh(a,b,c,d){var e=0,f=b.length;for(;e<f;e++)$(a,b[e],c,d)}function bi(a,b,c,d,e,g){var h,i=f.setFilters[b.toLowerCase()];return i||$.error(b),(a||!(h=e))&&bh(a||"*",d,h=[],e),h.length>0?i(h,c,g):[]}function bj(a,c,d,e){var f,g,h,i,j,k,l,m,n,o,p,q,r,s=0,t=a.length,v=S.POS,w=new RegExp("^"+v.source+"(?!"+A+")","i"),x=function(){var a=1,c=arguments.length-2;for(;a<c;a++)arguments[a]===b&&(n[a]=b)};for(;s<t;s++){f=a[s],g="",m=e;for(h=0,i=f.length;h<i;h++){j=f[h],k=j.string;if(j.part==="PSEUDO"){v.exec(""),l=0;while(n=v.exec(k)){o=!0,p=v.lastIndex=n.index+n[0].length;if(p>l){g+=k.slice(l,n.index),l=p,q=[c],J.test(g)&&(m&&(q=m),m=e);if(r=O.test(g))g=g.slice(0,-5).replace(J,"$&*"),l++;n.length>1&&n[0].replace(w,x),m=bi(g,n[1],n[2],q,m,r)}g=""}}o||(g+=k),o=!1}g?J.test(g)?bh(g,m||[c],d,e):$(g,c,d,e?e.concat(m):m):u.apply(d,m)}return t===1?d:$.uniqueSort(d)}function bk(a,b,e,g,h){a=a.replace(H,"$1");var i,k,l,m,n,o,p,q,r,s,v=bc(a,b,h),w=b.nodeType;if(S.POS.test(a))return bj(v,b,e,g);if(g)i=t.call(g,0);else if(v.length===1){if((o=t.call(v[0],0)).length>2&&(p=o[0]).part==="ID"&&w===9&&!h&&f.relative[o[1].part]){b=f.find.ID(p.captures[0].replace(R,""),b,h)[0];if(!b)return e;a=a.slice(o.shift().string.length)}r=(v=N.exec(o[0].string))&&!v.index&&b.parentNode||b,q="";for(n=o.length-1;n>=0;n--){p=o[n],s=p.part,q=p.string+q;if(f.relative[s])break;if(f.order.test(s)){i=f.find[s](p.captures[0].replace(R,""),r,h);if(i==null)continue;a=a.slice(0,a.length-q.length)+q.replace(S[s],""),a||u.apply(e,t.call(i,0));break}}}if(a){k=j(a,b,h),c=k.dirruns++,i==null&&(i=f.find.TAG("*",N.test(a)&&b.parentNode||b));for(n=0;m=i[n];n++)d=k.runs++,k(m)&&e.push(m)}return e}var c,d,e,f,g,h,i,j,k,l,m=!0,n="undefined",o=("sizcache"+Math.random()).replace(".",""),q=a.document,r=q.documentElement,s=0,t=[].slice,u=[].push,v=function(a,b){return a[o]=b||!0,a},w=function(){var a={},b=[];return v(function(c,d){return b.push(c)>f.cacheLength&&delete a[b.shift()],a[c]=d},a)},x=w(),y=w(),z=w(),A="[\\x20\\t\\r\\n\\f]",B="(?:\\\\.|[-\\w]|[^\\x00-\\xa0])+",C=B.replace("w","w#"),D="([*^$|!~]?=)",E="\\["+A+"*("+B+")"+A+"*(?:"+D+A+"*(?:([''\"])((?:\\\\.|[^\\\\])*?)\\3|("+C+")|)|)"+A+"*\\]",F=":("+B+")(?:\\((?:([''\"])((?:\\\\.|[^\\\\])*?)\\2|([^()[\\]]*|(?:(?:"+E+")|[^:]|\\\\.)*|.*))\\)|)",G=":(nth|eq|gt|lt|first|last|even|odd)(?:\\(((?:-\\d)?\\d*)\\)|)(?=[^-]|$)",H=new RegExp("^"+A+"+|((?:^|[^\\\\])(?:\\\\.)*)"+A+"+$","g"),I=new RegExp("^"+A+"*,"+A+"*"),J=new RegExp("^"+A+"*([\\x20\\t\\r\\n\\f>+~])"+A+"*"),K=new RegExp(F),L=/^(?:#([\w\-]+)|(\w+)|\.([\w\-]+))$/,M=/^:not/,N=/[\x20\t\r\n\f]*[+~]/,O=/:not\($/,P=/h\d/i,Q=/input|select|textarea|button/i,R=/\\(?!\\)/g,S={ID:new RegExp("^#("+B+")"),CLASS:new RegExp("^\\.("+B+")"),NAME:new RegExp("^\\[name=[''\"]?("+B+")[''\"]?\\]"),TAG:new RegExp("^("+B.replace("w","w*")+")"),ATTR:new RegExp("^"+E),PSEUDO:new RegExp("^"+F),CHILD:new RegExp("^:(only|nth|last|first)-child(?:\\("+A+"*(even|odd|(([+-]|)(\\d*)n|)"+A+"*(?:([+-]|)"+A+"*(\\d+)|))"+A+"*\\)|)","i"),POS:new RegExp(G,"ig"),needsContext:new RegExp("^"+A+"*[>+~]|"+G,"i")},T=function(a){var b=q.createElement("div");try{return a(b)}catch(c){return!1}finally{b=null}},U=T(function(a){return a.appendChild(q.createComment("")),!a.getElementsByTagName("*").length}),V=T(function(a){return a.innerHTML="<a href=''#''></a>",a.firstChild&&typeof a.firstChild.getAttribute!==n&&a.firstChild.getAttribute("href")==="#"}),W=T(function(a){a.innerHTML="<select></select>";var b=typeof a.lastChild.getAttribute("multiple");return b!=="boolean"&&b!=="string"}),X=T(function(a){return a.innerHTML="<div class=''hidden e''></div><div class=''hidden''></div>",!a.getElementsByClassName||!a.getElementsByClassName("e").length?!1:(a.lastChild.className="e",a.getElementsByClassName("e").length===2)}),Y=T(function(a){a.id=o+0,a.innerHTML="<a name=''"+o+"''></a><div name=''"+o+"''></div>",r.insertBefore(a,r.firstChild);var b=q.getElementsByName&&q.getElementsByName(o).length===2+q.getElementsByName(o+0).length;return e=!q.getElementById(o),r.removeChild(a),b});try{t.call(r.childNodes,0)[0].nodeType}catch(Z){t=function(a){var b,c=[];for(;b=this[a];a++)c.push(b);return c}}$.matches=function(a,b){return $(a,null,null,b)},$.matchesSelector=function(a,b){return $(b,null,null,[a]).length>0},g=$.getText=function(a){var b,c="",d=0,e=a.nodeType;if(e){if(e===1||e===9||e===11){if(typeof a.textContent=="string")return a.textContent;for(a=a.firstChild;a;a=a.nextSibling)c+=g(a)}else if(e===3||e===4)return a.nodeValue}else for(;b=a[d];d++)c+=g(b);return c},h=$.isXML=function(a){var b=a&&(a.ownerDocument||a).documentElement;return b?b.nodeName!=="HTML":!1},i=$.contains=r.contains?function(a,b){var c=a.nodeType===9?a.documentElement:a,d=b&&b.parentNode;return a===d||!!(d&&d.nodeType===1&&c.contains&&c.contains(d))}:r.compareDocumentPosition?function(a,b){return b&&!!(a.compareDocumentPosition(b)&16)}:function(a,b){while(b=b.parentNode)if(b===a)return!0;return!1},$.attr=function(a,b){var c,d=h(a);return d||(b=b.toLowerCase()),f.attrHandle[b]?f.attrHandle[b](a):W||d?a.getAttribute(b):(c=a.getAttributeNode(b),c?typeof a[b]=="boolean"?a[b]?b:null:c.specified?c.value:null:null)},f=$.selectors={cacheLength:50,createPseudo:v,match:S,order:new RegExp("ID|TAG"+(Y?"|NAME":"")+(X?"|CLASS":"")),attrHandle:V?{}:{href:function(a){return a.getAttribute("href",2)},type:function(a){return a.getAttribute("type")}},find:{ID:e?function(a,b,c){if(typeof b.getElementById!==n&&!c){var d=b.getElementById(a);return d&&d.parentNode?[d]:[]}}:function(a,c,d){if(typeof c.getElementById!==n&&!d){var e=c.getElementById(a);return e?e.id===a||typeof e.getAttributeNode!==n&&e.getAttributeNode("id").value===a?[e]:b:[]}},TAG:U?function(a,b){if(typeof b.getElementsByTagName!==n)return b.getElementsByTagName(a)}:function(a,b){var c=b.getElementsByTagName(a);if(a==="*"){var d,e=[],f=0;for(;d=c[f];f++)d.nodeType===1&&e.push(d);return e}return c},NAME:function(a,b){if(typeof b.getElementsByName!==n)return b.getElementsByName(name)},CLASS:function(a,b,c){if(typeof b.getElementsByClassName!==n&&!c)return b.getElementsByClassName(a)}},relative:{">":{dir:"parentNode",first:!0}," ":{dir:"parentNode"},"+":{dir:"previousSibling",first:!0},"~":{dir:"previousSibling"}},preFilter:{ATTR:function(a){return a[1]=a[1].replace(R,""),a[3]=(a[4]||a[5]||"").replace(R,""),a[2]==="~="&&(a[3]=" "+a[3]+" "),a.slice(0,4)},CHILD:function(a){return a[1]=a[1].toLowerCase(),a[1]==="nth"?(a[2]||$.error(a[0]),a[3]=+(a[3]?a[4]+(a[5]||1):2*(a[2]==="even"||a[2]==="odd")),a[4]=+(a[6]+a[7]||a[2]==="odd")):a[2]&&$.error(a[0]),a},PSEUDO:function(a,b,c){var d,e;if(S.CHILD.test(a[0]))return null;if(a[3])a[2]=a[3];else if(d=a[4])K.test(d)&&(e=bc(d,b,c,!0))&&(e=d.indexOf(")",d.length-e)-d.length)&&(d=d.slice(0,e),a[0]=a[0].slice(0,e)),a[2]=d;return a.slice(0,3)}},filter:{ID:e?function(a){return a=a.replace(R,""),function(b){return b.getAttribute("id")===a}}:function(a){return a=a.replace(R,""),function(b){var c=typeof b.getAttributeNode!==n&&b.getAttributeNode("id");return c&&c.value===a}},TAG:function(a){return a==="*"?function(){return!0}:(a=a.replace(R,"").toLowerCase(),function(b){return b.nodeName&&b.nodeName.toLowerCase()===a})},CLASS:function(a){var b=x[o][a];return b||(b=x(a,new RegExp("(^|"+A+")"+a+"("+A+"|$)"))),function(a){return b.test(a.className||typeof a.getAttribute!==n&&a.getAttribute("class")||"")}},ATTR:function(a,b,c){return b?function(d){var e=$.attr(d,a),f=e+"";if(e==null)return b==="!=";switch(b){case"=":return f===c;case"!=":return f!==c;case"^=":return c&&f.indexOf(c)===0;case"*=":return c&&f.indexOf(c)>-1;case"$=":return c&&f.substr(f.length-c.length)===c;case"~=":return(" "+f+" ").indexOf(c)>-1;case"|=":return f===c||f.substr(0,c.length+1)===c+"-"}}:function(b){return $.attr(b,a)!=null}},CHILD:function(a,b,c,d){if(a==="nth"){var e=s++;return function(a){var b,f,g=0,h=a;if(c===1&&d===0)return!0;b=a.parentNode;if(b&&(b[o]!==e||!a.sizset)){for(h=b.firstChild;h;h=h.nextSibling)if(h.nodeType===1){h.sizset=++g;if(h===a)break}b[o]=e}return f=a.sizset-d,c===0?f===0:f%c===0&&f/c>=0}}return function(b){var c=b;switch(a){case"only":case"first":while(c=c.previousSibling)if(c.nodeType===1)return!1;if(a==="first")return!0;c=b;case"last":while(c=c.nextSibling)if(c.nodeType===1)return!1;return!0}}},PSEUDO:function(a,b,c,d){var e,g=f.pseudos[a]||f.pseudos[a.toLowerCase()];return g||$.error("unsupported pseudo: "+a),g[o]?g(b,c,d):g.length>1?(e=[a,a,"",b],function(a){return g(a,0,e)}):g}},pseudos:{not:v(function(a,b,c){var d=j(a.replace(H,"$1"),b,c);return function(a){return!d(a)}}),enabled:function(a){return a.disabled===!1},disabled:function(a){return a.disabled===!0},checked:function(a){var b=a.nodeName.toLowerCase();return b==="input"&&!!a.checked||b==="option"&&!!a.selected},selected:function(a){return a.parentNode&&a.parentNode.selectedIndex,a.selected===!0},parent:function(a){return!f.pseudos.empty(a)},empty:function(a){var b;a=a.firstChild;while(a){if(a.nodeName>"@"||(b=a.nodeType)===3||b===4)return!1;a=a.nextSibling}return!0},contains:v(function(a){return function(b){return(b.textContent||b.innerText||g(b)).indexOf(a)>-1}}),has:v(function(a){return function(b){return $(a,b).length>0}}),header:function(a){return P.test(a.nodeName)},text:function(a){var b,c;return a.nodeName.toLowerCase()==="input"&&(b=a.type)==="text"&&((c=a.getAttribute("type"))==null||c.toLowerCase()===b)},radio:_("radio"),checkbox:_("checkbox"),file:_("file"),password:_("password"),image:_("image"),submit:ba("submit"),reset:ba("reset"),button:function(a){var b=a.nodeName.toLowerCase();return b==="input"&&a.type==="button"||b==="button"},input:function(a){return Q.test(a.nodeName)},focus:function(a){var b=a.ownerDocument;return a===b.activeElement&&(!b.hasFocus||b.hasFocus())&&(!!a.type||!!a.href)},active:function(a){return a===a.ownerDocument.activeElement}},setFilters:{first:function(a,b,c){return c?a.slice(1):[a[0]]},last:function(a,b,c){var d=a.pop();return c?a:[d]},even:function(a,b,c){var d=[],e=c?1:0,f=a.length;for(;e<f;e=e+2)d.push(a[e]);return d},odd:function(a,b,c){var d=[],e=c?0:1,f=a.length;for(;e<f;e=e+2)d.push(a[e]);return d},lt:function(a,b,c){return c?a.slice(+b):a.slice(0,+b)},gt:function(a,b,c){return c?a.slice(0,+b+1):a.slice(+b+1)},eq:function(a,b,c){var d=a.splice(+b,1);return c?a:d}}},k=r.compareDocumentPosition?function(a,b){return a===b?(l=!0,0):(!a.compareDocumentPosition||!b.compareDocumentPosition?a.compareDocumentPosition:a.compareDocumentPosition(b)&4)?-1:1}:function(a,b){if(a===b)return l=!0,0;if(a.sourceIndex&&b.sourceIndex)return a.sourceIndex-b.sourceIndex;var c,d,e=[],f=[],g=a.parentNode,h=b.parentNode,i=g;if(g===h)return bb(a,b);if(!g)return-1;if(!h)return 1;while(i)e.unshift(i),i=i.parentNode;i=h;while(i)f.unshift(i),i=i.parentNode;c=e.length,d=f.length;for(var j=0;j<c&&j<d;j++)if(e[j]!==f[j])return bb(e[j],f[j]);return j===c?bb(a,f[j],-1):bb(e[j],b,1)},[0,0].sort(k),m=!l,$.uniqueSort=function(a){var b,c=1;l=m,a.sort(k);if(l)for(;b=a[c];c++)b===a[c-1]&&a.splice(c--,1);return a},$.error=function(a){throw new Error("Syntax error, unrecognized expression: "+a)},j=$.compile=function(a,b,c){var d,e,f,g=z[o][a];if(g&&g.context===b)return g;d=bc(a,b,c);for(e=0,f=d.length;e<f;e++)d[e]=bf(d[e],b,c);return g=z(a,bg(d)),g.context=b,g.runs=g.dirruns=0,g},q.querySelectorAll&&function(){var a,b=bk,c=/''|\\/g,d=/\=[\x20\t\r\n\f]*([^''"\]]*)[\x20\t\r\n\f]*\]/g,e=[],f=[":active"],g=r.matchesSelector||r.mozMatchesSelector||r.webkitMatchesSelector||r.oMatchesSelector||r.msMatchesSelector;T(function(a){a.innerHTML="<select><option selected=''''></option></select>",a.querySelectorAll("[selected]").length||e.push("\\["+A+"*(?:checked|disabled|ismap|multiple|readonly|selected|value)"),a.querySelectorAll(":checked").length||e.push(":checked")}),T(function(a){a.innerHTML="<p test=''''></p>",a.querySelectorAll("[test^='''']").length&&e.push("[*^$]="+A+"*(?:\"\"|'''')"),a.innerHTML="<input type=''hidden''/>",a.querySelectorAll(":enabled").length||e.push(":enabled",":disabled")}),e=e.length&&new RegExp(e.join("|")),bk=function(a,d,f,g,h){if(!g&&!h&&(!e||!e.test(a)))if(d.nodeType===9)try{return u.apply(f,t.call(d.querySelectorAll(a),0)),f}catch(i){}else if(d.nodeType===1&&d.nodeName.toLowerCase()!=="object"){var j,k,l,m=d.getAttribute("id"),n=m||o,p=N.test(a)&&d.parentNode||d;m?n=n.replace(c,"\\$&"):d.setAttribute("id",n),j=bc(a,d,h),n="[id=''"+n+"'']";for(k=0,l=j.length;k<l;k++)j[k]=n+j[k].selector;try{return u.apply(f,t.call(p.querySelectorAll(j.join(",")),0)),f}catch(i){}finally{m||d.removeAttribute("id")}}return b(a,d,f,g,h)},g&&(T(function(b){a=g.call(b,"div");try{g.call(b,"[test!='''']:sizzle"),f.push(S.PSEUDO.source,S.POS.source,"!=")}catch(c){}}),f=new RegExp(f.join("|")),$.matchesSelector=function(b,c){c=c.replace(d,"=''$1'']");if(!h(b)&&!f.test(c)&&(!e||!e.test(c)))try{var i=g.call(b,c);if(i||a||b.document&&b.document.nodeType!==11)return i}catch(j){}return $(c,null,null,[b]).length>0})}(),f.setFilters.nth=f.setFilters.eq,f.filters=f.pseudos,$.attr=p.attr,p.find=$,p.expr=$.selectors,p.expr[":"]=p.expr.pseudos,p.unique=$.uniqueSort,p.text=$.getText,p.isXMLDoc=$.isXML,p.contains=$.contains}(a);var bc=/Until$/,bd=/^(?:parents|prev(?:Until|All))/,be=/^.[^:#\[\.,]*$/,bf=p.expr.match.needsContext,bg={children:!0,contents:!0,next:!0,prev:!0};p.fn.extend({find:function(a){var b,c,d,e,f,g,h=this;if(typeof a!="string")return p(a).filter(function(){for(b=0,c=h.length;b<c;b++)if(p.contains(h[b],this))return!0});g=this.pushStack("","find",a);for(b=0,c=this.length;b<c;b++){d=g.length,p.find(a,this[b],g);if(b>0)for(e=d;e<g.length;e++)for(f=0;f<d;f++)if(g[f]===g[e]){g.splice(e--,1);break}}return g},has:function(a){var b,c=p(a,this),d=c.length;return this.filter(function(){for(b=0;b<d;b++)if(p.contains(this,c[b]))return!0})},not:function(a){return this.pushStack(bj(this,a,!1),"not",a)},filter:function(a){return this.pushStack(bj(this,a,!0),"filter",a)},is:function(a){return!!a&&(typeof a=="string"?bf.test(a)?p(a,this.context).index(this[0])>=0:p.filter(a,this).length>0:this.filter(a).length>0)},closest:function(a,b){var c,d=0,e=this.length,f=[],g=bf.test(a)||typeof a!="string"?p(a,b||this.context):0;for(;d<e;d++){c=this[d];while(c&&c.ownerDocument&&c!==b&&c.nodeType!==11){if(g?g.index(c)>-1:p.find.matchesSelector(c,a)){f.push(c);break}c=c.parentNode}}return f=f.length>1?p.unique(f):f,this.pushStack(f,"closest",a)},index:function(a){return a?typeof a=="string"?p.inArray(this[0],p(a)):p.inArray(a.jquery?a[0]:a,this):this[0]&&this[0].parentNode?this.prevAll().length:-1},add:function(a,b){var c=typeof a=="string"?p(a,b):p.makeArray(a&&a.nodeType?[a]:a),d=p.merge(this.get(),c);return this.pushStack(bh(c[0])||bh(d[0])?d:p.unique(d))},addBack:function(a){return this.add(a==null?this.prevObject:this.prevObject.filter(a))}}),p.fn.andSelf=p.fn.addBack,p.each({parent:function(a){var b=a.parentNode;return b&&b.nodeType!==11?b:null},parents:function(a){return p.dir(a,"parentNode")},parentsUntil:function(a,b,c){return p.dir(a,"parentNode",c)},next:function(a){return bi(a,"nextSibling")},prev:function(a){return bi(a,"previousSibling")},nextAll:function(a){return p.dir(a,"nextSibling")},prevAll:function(a){return p.dir(a,"previousSibling")},nextUntil:function(a,b,c){return p.dir(a,"nextSibling",c)},prevUntil:function(a,b,c){return p.dir(a,"previousSibling",c)},siblings:function(a){return p.sibling((a.parentNode||{}).firstChild,a)},children:function(a){return p.sibling(a.firstChild)},contents:function(a){return p.nodeName(a,"iframe")?a.contentDocument||a.contentWindow.document:p.merge([],a.childNodes)}},function(a,b){p.fn[a]=function(c,d){var e=p.map(this,b,c);return bc.test(a)||(d=c),d&&typeof d=="string"&&(e=p.filter(d,e)),e=this.length>1&&!bg[a]?p.unique(e):e,this.length>1&&bd.test(a)&&(e=e.reverse()),this.pushStack(e,a,k.call(arguments).join(","))}}),p.extend({filter:function(a,b,c){return c&&(a=":not("+a+")"),b.length===1?p.find.matchesSelector(b[0],a)?[b[0]]:[]:p.find.matches(a,b)},dir:function(a,c,d){var e=[],f=a[c];while(f&&f.nodeType!==9&&(d===b||f.nodeType!==1||!p(f).is(d)))f.nodeType===1&&e.push(f),f=f[c];return e},sibling:function(a,b){var c=[];for(;a;a=a.nextSibling)a.nodeType===1&&a!==b&&c.push(a);return c}});var bl="abbr|article|aside|audio|bdi|canvas|data|datalist|details|figcaption|figure|footer|header|hgroup|mark|meter|nav|output|progress|section|summary|time|video",bm=/ jQuery\d+="(?:null|\d+)"/g,bn=/^\s+/,bo=/<(?!area|br|col|embed|hr|img|input|link|meta|param)(([\w:]+)[^>]*)\/>/gi,bp=/<([\w:]+)/,bq=/<tbody/i,br=/<|&#?\w+;/,bs=/<(?:script|style|link)/i,bt=/<(?:script|object|embed|option|style)/i,bu=new RegExp("<(?:"+bl+")[\\s/>]","i"),bv=/^(?:checkbox|radio)$/,bw=/checked\s*(?:[^=]|=\s*.checked.)/i,bx=/\/(java|ecma)script/i,by=/^\s*<!(?:\[CDATA\[|\-\-)|[\]\-]{2}>\s*$/g,bz={option:[1,"<select multiple=''multiple''>","</select>"],legend:[1,"<fieldset>","</fieldset>"],thead:[1,"<table>","</table>"],tr:[2,"<table><tbody>","</tbody></table>"],td:[3,"<table><tbody><tr>","</tr></tbody></table>"],col:[2,"<table><tbody></tbody><colgroup>","</colgroup></table>"],area:[1,"<map>","</map>"],_default:[0,"",""]},bA=bk(e),bB=bA.appendChild(e.createElement("div"));bz.optgroup=bz.option,bz.tbody=bz.tfoot=bz.colgroup=bz.caption=bz.thead,bz.th=bz.td,p.support.htmlSerialize||(bz._default=[1,"X<div>","</div>"]),p.fn.extend({text:function(a){return p.access(this,function(a){return a===b?p.text(this):this.empty().append((this[0]&&this[0].ownerDocument||e).createTextNode(a))},null,a,arguments.length)},wrapAll:function(a){if(p.isFunction(a))return this.each(function(b){p(this).wrapAll(a.call(this,b))});if(this[0]){var b=p(a,this[0].ownerDocument).eq(0).clone(!0);this[0].parentNode&&b.insertBefore(this[0]),b.map(function(){var a=this;while(a.firstChild&&a.firstChild.nodeType===1)a=a.firstChild;return a}).append(this)}return this},wrapInner:function(a){return p.isFunction(a)?this.each(function(b){p(this).wrapInner(a.call(this,b))}):this.each(function(){var b=p(this),c=b.contents();c.length?c.wrapAll(a):b.append(a)})},wrap:function(a){var b=p.isFunction(a);return this.each(function(c){p(this).wrapAll(b?a.call(this,c):a)})},unwrap:function(){return this.parent().each(function(){p.nodeName(this,"body")||p(this).replaceWith(this.childNodes)}).end()},append:function(){return this.domManip(arguments,!0,function(a){(this.nodeType===1||this.nodeType===11)&&this.appendChild(a)})},prepend:function(){return this.domManip(arguments,!0,function(a){(this.nodeType===1||this.nodeType===11)&&this.insertBefore(a,this.firstChild)})},before:function(){if(!bh(this[0]))return this.domManip(arguments,!1,function(a){this.parentNode.insertBefore(a,this)});if(arguments.length){var a=p.clean(arguments);return this.pushStack(p.merge(a,this),"before",this.selector)}},after:function(){if(!bh(this[0]))return this.domManip(arguments,!1,function(a){this.parentNode.insertBefore(a,this.nextSibling)});if(arguments.length){var a=p.clean(arguments);return this.pushStack(p.merge(this,a),"after",this.selector)}},remove:function(a,b){var c,d=0;for(;(c=this[d])!=null;d++)if(!a||p.filter(a,[c]).length)!b&&c.nodeType===1&&(p.cleanData(c.getElementsByTagName("*")),p.cleanData([c])),c.parentNode&&c.parentNode.removeChild(c);return this},empty:function(){var a,b=0;for(;(a=this[b])!=null;b++){a.nodeType===1&&p.cleanData(a.getElementsByTagName("*"));while(a.firstChild)a.removeChild(a.firstChild)}return this},clone:function(a,b){return a=a==null?!1:a,b=b==null?a:b,this.map(function(){return p.clone(this,a,b)})},html:function(a){return p.access(this,function(a){var c=this[0]||{},d=0,e=this.length;if(a===b)return c.nodeType===1?c.innerHTML.replace(bm,""):b;if(typeof a=="string"&&!bs.test(a)&&(p.support.htmlSerialize||!bu.test(a))&&(p.support.leadingWhitespace||!bn.test(a))&&!bz[(bp.exec(a)||["",""])[1].toLowerCase()]){a=a.replace(bo,"<$1></$2>");try{for(;d<e;d++)c=this[d]||{},c.nodeType===1&&(p.cleanData(c.getElementsByTagName("*")),c.innerHTML=a);c=0}catch(f){}}c&&this.empty().append(a)},null,a,arguments.length)},replaceWith:function(a){return bh(this[0])?this.length?this.pushStack(p(p.isFunction(a)?a():a),"replaceWith",a):this:p.isFunction(a)?this.each(function(b){var c=p(this),d=c.html();c.replaceWith(a.call(this,b,d))}):(typeof a!="string"&&(a=p(a).detach()),this.each(function(){var b=this.nextSibling,c=this.parentNode;p(this).remove(),b?p(b).before(a):p(c).append(a)}))},detach:function(a){return this.remove(a,!0)},domManip:function(a,c,d){a=[].concat.apply([],a);var e,f,g,h,i=0,j=a[0],k=[],l=this.length;if(!p.support.checkClone&&l>1&&typeof j=="string"&&bw.test(j))return this.each(function(){p(this).domManip(a,c,d)});if(p.isFunction(j))return this.each(function(e){var f=p(this);a[0]=j.call(this,e,c?f.html():b),f.domManip(a,c,d)});if(this[0]){e=p.buildFragment(a,this,k),g=e.fragment,f=g.firstChild,g.childNodes.length===1&&(g=f);if(f){c=c&&p.nodeName(f,"tr");for(h=e.cacheable||l-1;i<l;i++)d.call(c&&p.nodeName(this[i],"table")?bC(this[i],"tbody"):this[i],i===h?g:p.clone(g,!0,!0))}g=f=null,k.length&&p.each(k,function(a,b){b.src?p.ajax?p.ajax({url:b.src,type:"GET",dataType:"script",async:!1,global:!1,"throws":!0}):p.error("no ajax"):p.globalEval((b.text||b.textContent||b.innerHTML||"").replace(by,"")),b.parentNode&&b.parentNode.removeChild(b)})}return this}}),p.buildFragment=function(a,c,d){var f,g,h,i=a[0];return c=c||e,c=!c.nodeType&&c[0]||c,c=c.ownerDocument||c,a.length===1&&typeof i=="string"&&i.length<512&&c===e&&i.charAt(0)==="<"&&!bt.test(i)&&(p.support.checkClone||!bw.test(i))&&(p.support.html5Clone||!bu.test(i))&&(g=!0,f=p.fragments[i],h=f!==b),f||(f=c.createDocumentFragment(),p.clean(a,c,f,d),g&&(p.fragments[i]=h&&f)),{fragment:f,cacheable:g}},p.fragments={},p.each({appendTo:"append",prependTo:"prepend",insertBefore:"before",insertAfter:"after",replaceAll:"replaceWith"},function(a,b){p.fn[a]=function(c){var d,e=0,f=[],g=p(c),h=g.length,i=this.length===1&&this[0].parentNode;if((i==null||i&&i.nodeType===11&&i.childNodes.length===1)&&h===1)return g[b](this[0]),this;for(;e<h;e++)d=(e>0?this.clone(!0):this).get(),p(g[e])[b](d),f=f.concat(d);return this.pushStack(f,a,g.selector)}}),p.extend({clone:function(a,b,c){var d,e,f,g;p.support.html5Clone||p.isXMLDoc(a)||!bu.test("<"+a.nodeName+">")?g=a.cloneNode(!0):(bB.innerHTML=a.outerHTML,bB.removeChild(g=bB.firstChild));if((!p.support.noCloneEvent||!p.support.noCloneChecked)&&(a.nodeType===1||a.nodeType===11)&&!p.isXMLDoc(a)){bE(a,g),d=bF(a),e=bF(g);for(f=0;d[f];++f)e[f]&&bE(d[f],e[f])}if(b){bD(a,g);if(c){d=bF(a),e=bF(g);for(f=0;d[f];++f)bD(d[f],e[f])}}return d=e=null,g},clean:function(a,b,c,d){var f,g,h,i,j,k,l,m,n,o,q,r,s=b===e&&bA,t=[];if(!b||typeof b.createDocumentFragment=="undefined")b=e;for(f=0;(h=a[f])!=null;f++){typeof h=="number"&&(h+="");if(!h)continue;if(typeof h=="string")if(!br.test(h))h=b.createTextNode(h);else{s=s||bk(b),l=b.createElement("div"),s.appendChild(l),h=h.replace(bo,"<$1></$2>"),i=(bp.exec(h)||["",""])[1].toLowerCase(),j=bz[i]||bz._default,k=j[0],l.innerHTML=j[1]+h+j[2];while(k--)l=l.lastChild;if(!p.support.tbody){m=bq.test(h),n=i==="table"&&!m?l.firstChild&&l.firstChild.childNodes:j[1]==="<table>"&&!m?l.childNodes:[];for(g=n.length-1;g>=0;--g)p.nodeName(n[g],"tbody")&&!n[g].childNodes.length&&n[g].parentNode.removeChild(n[g])}!p.support.leadingWhitespace&&bn.test(h)&&l.insertBefore(b.createTextNode(bn.exec(h)[0]),l.firstChild),h=l.childNodes,l.parentNode.removeChild(l)}h.nodeType?t.push(h):p.merge(t,h)}l&&(h=l=s=null);if(!p.support.appendChecked)for(f=0;(h=t[f])!=null;f++)p.nodeName(h,"input")?bG(h):typeof h.getElementsByTagName!="undefined"&&p.grep(h.getElementsByTagName("input"),bG);if(c){q=function(a){if(!a.type||bx.test(a.type))return d?d.push(a.parentNode?a.parentNode.removeChild(a):a):c.appendChild(a)};for(f=0;(h=t[f])!=null;f++)if(!p.nodeName(h,"script")||!q(h))c.appendChild(h),typeof h.getElementsByTagName!="undefined"&&(r=p.grep(p.merge([],h.getElementsByTagName("script")),q),t.splice.apply(t,[f+1,0].concat(r)),f+=r.length)}return t},cleanData:function(a,b){var c,d,e,f,g=0,h=p.expando,i=p.cache,j=p.support.deleteExpando,k=p.event.special;for(;(e=a[g])!=null;g++)if(b||p.acceptData(e)){d=e[h],c=d&&i[d];if(c){if(c.events)for(f in c.events)k[f]?p.event.remove(e,f):p.removeEvent(e,f,c.handle);i[d]&&(delete i[d],j?delete e[h]:e.removeAttribute?e.removeAttribute(h):e[h]=null,p.deletedIds.push(d))}}}}),function(){var a,b;p.uaMatch=function(a){a=a.toLowerCase();var b=/(chrome)[ \/]([\w.]+)/.exec(a)||/(webkit)[ \/]([\w.]+)/.exec(a)||/(opera)(?:.*version|)[ \/]([\w.]+)/.exec(a)||/(msie) ([\w.]+)/.exec(a)||a.indexOf("compatible")<0&&/(mozilla)(?:.*? rv:([\w.]+)|)/.exec(a)||[];return{browser:b[1]||"",version:b[2]||"0"}},a=p.uaMatch(g.userAgent),b={},a.browser&&(b[a.browser]=!0,b.version=a.version),b.chrome?b.webkit=!0:b.webkit&&(b.safari=!0),p.browser=b,p.sub=function(){function a(b,c){return new a.fn.init(b,c)}p.extend(!0,a,this),a.superclass=this,a.fn=a.prototype=this(),a.fn.constructor=a,a.sub=this.sub,a.fn.init=function c(c,d){return d&&d instanceof p&&!(d instanceof a)&&(d=a(d)),p.fn.init.call(this,c,d,b)},a.fn.init.prototype=a.fn;var b=a(e);return a}}();var bH,bI,bJ,bK=/alpha\([^)]*\)/i,bL=/opacity=([^)]*)/,bM=/^(top|right|bottom|left)$/,bN=/^(none|table(?!-c[ea]).+)/,bO=/^margin/,bP=new RegExp("^("+q+")(.*)$","i"),bQ=new RegExp("^("+q+")(?!px)[a-z%]+$","i"),bR=new RegExp("^([-+])=("+q+")","i"),bS={},bT={position:"absolute",visibility:"hidden",display:"block"},bU={letterSpacing:0,fontWeight:400},bV=["Top","Right","Bottom","Left"],bW=["Webkit","O","Moz","ms"],bX=p.fn.toggle;p.fn.extend({css:function(a,c){return p.access(this,function(a,c,d){return d!==b?p.style(a,c,d):p.css(a,c)},a,c,arguments.length>1)},show:function(){return b$(this,!0)},hide:function(){return b$(this)},toggle:function(a,b){var c=typeof a=="boolean";return p.isFunction(a)&&p.isFunction(b)?bX.apply(this,arguments):this.each(function(){(c?a:bZ(this))?p(this).show():p(this).hide()})}}),p.extend({cssHooks:{opacity:{get:function(a,b){if(b){var c=bH(a,"opacity");return c===""?"1":c}}}},cssNumber:{fillOpacity:!0,fontWeight:!0,lineHeight:!0,opacity:!0,orphans:!0,widows:!0,zIndex:!0,zoom:!0},cssProps:{"float":p.support.cssFloat?"cssFloat":"styleFloat"},style:function(a,c,d,e){if(!a||a.nodeType===3||a.nodeType===8||!a.style)return;var f,g,h,i=p.camelCase(c),j=a.style;c=p.cssProps[i]||(p.cssProps[i]=bY(j,i)),h=p.cssHooks[c]||p.cssHooks[i];if(d===b)return h&&"get"in h&&(f=h.get(a,!1,e))!==b?f:j[c];g=typeof d,g==="string"&&(f=bR.exec(d))&&(d=(f[1]+1)*f[2]+parseFloat(p.css(a,c)),g="number");if(d==null||g==="number"&&isNaN(d))return;g==="number"&&!p.cssNumber[i]&&(d+="px");if(!h||!("set"in h)||(d=h.set(a,d,e))!==b)try{j[c]=d}catch(k){}},css:function(a,c,d,e){var f,g,h,i=p.camelCase(c);return c=p.cssProps[i]||(p.cssProps[i]=bY(a.style,i)),h=p.cssHooks[c]||p.cssHooks[i],h&&"get"in h&&(f=h.get(a,!0,e)),f===b&&(f=bH(a,c)),f==="normal"&&c in bU&&(f=bU[c]),d||e!==b?(g=parseFloat(f),d||p.isNumeric(g)?g||0:f):f},swap:function(a,b,c){var d,e,f={};for(e in b)f[e]=a.style[e],a.style[e]=b[e];d=c.call(a);for(e in b)a.style[e]=f[e];return d}}),a.getComputedStyle?bH=function(b,c){var d,e,f,g,h=a.getComputedStyle(b,null),i=b.style;return h&&(d=h[c],d===""&&!p.contains(b.ownerDocument,b)&&(d=p.style(b,c)),bQ.test(d)&&bO.test(c)&&(e=i.width,f=i.minWidth,g=i.maxWidth,i.minWidth=i.maxWidth=i.width=d,d=h.width,i.width=e,i.minWidth=f,i.maxWidth=g)),d}:e.documentElement.currentStyle&&(bH=function(a,b){var c,d,e=a.currentStyle&&a.currentStyle[b],f=a.style;return e==null&&f&&f[b]&&(e=f[b]),bQ.test(e)&&!bM.test(b)&&(c=f.left,d=a.runtimeStyle&&a.runtimeStyle.left,d&&(a.runtimeStyle.left=a.currentStyle.left),f.left=b==="fontSize"?"1em":e,e=f.pixelLeft+"px",f.left=c,d&&(a.runtimeStyle.left=d)),e===""?"auto":e}),p.each(["height","width"],function(a,b){p.cssHooks[b]={get:function(a,c,d){if(c)return a.offsetWidth===0&&bN.test(bH(a,"display"))?p.swap(a,bT,function(){return cb(a,b,d)}):cb(a,b,d)},set:function(a,c,d){return b_(a,c,d?ca(a,b,d,p.support.boxSizing&&p.css(a,"boxSizing")==="border-box"):0)}}}),p.support.opacity||(p.cssHooks.opacity={get:function(a,b){return bL.test((b&&a.currentStyle?a.currentStyle.filter:a.style.filter)||"")?.01*parseFloat(RegExp.$1)+"":b?"1":""},set:function(a,b){var c=a.style,d=a.currentStyle,e=p.isNumeric(b)?"alpha(opacity="+b*100+")":"",f=d&&d.filter||c.filter||"";c.zoom=1;if(b>=1&&p.trim(f.replace(bK,""))===""&&c.removeAttribute){c.removeAttribute("filter");if(d&&!d.filter)return}c.filter=bK.test(f)?f.replace(bK,e):f+" "+e}}),p(function(){p.support.reliableMarginRight||(p.cssHooks.marginRight={get:function(a,b){return p.swap(a,{display:"inline-block"},function(){if(b)return bH(a,"marginRight")})}}),!p.support.pixelPosition&&p.fn.position&&p.each(["top","left"],function(a,b){p.cssHooks[b]={get:function(a,c){if(c){var d=bH(a,b);return bQ.test(d)?p(a).position()[b]+"px":d}}}})}),p.expr&&p.expr.filters&&(p.expr.filters.hidden=function(a){return a.offsetWidth===0&&a.offsetHeight===0||!p.support.reliableHiddenOffsets&&(a.style&&a.style.display||bH(a,"display"))==="none"},p.expr.filters.visible=function(a){return!p.expr.filters.hidden(a)}),p.each({margin:"",padding:"",border:"Width"},function(a,b){p.cssHooks[a+b]={expand:function(c){var d,e=typeof c=="string"?c.split(" "):[c],f={};for(d=0;d<4;d++)f[a+bV[d]+b]=e[d]||e[d-2]||e[0];return f}},bO.test(a)||(p.cssHooks[a+b].set=b_)});var cd=/%20/g,ce=/\[\]$/,cf=/\r?\n/g,cg=/^(?:color|date|datetime|datetime-local|email|hidden|month|number|password|range|search|tel|text|time|url|week)$/i,ch=/^(?:select|textarea)/i;p.fn.extend({serialize:function(){return p.param(this.serializeArray())},serializeArray:function(){return this.map(function(){return this.elements?p.makeArray(this.elements):this}).filter(function(){return this.name&&!this.disabled&&(this.checked||ch.test(this.nodeName)||cg.test(this.type))}).map(function(a,b){var c=p(this).val();return c==null?null:p.isArray(c)?p.map(c,function(a,c){return{name:b.name,value:a.replace(cf,"\r\n")}}):{name:b.name,value:c.replace(cf,"\r\n")}}).get()}}),p.param=function(a,c){var d,e=[],f=function(a,b){b=p.isFunction(b)?b():b==null?"":b,e[e.length]=encodeURIComponent(a)+"="+encodeURIComponent(b)};c===b&&(c=p.ajaxSettings&&p.ajaxSettings.traditional);if(p.isArray(a)||a.jquery&&!p.isPlainObject(a))p.each(a,function(){f(this.name,this.value)});else for(d in a)ci(d,a[d],c,f);return e.join("&").replace(cd,"+")};var cj,ck,cl=/#.*$/,cm=/^(.*?):[ \t]*([^\r\n]*)\r?$/mg,cn=/^(?:about|app|app\-storage|.+\-extension|file|res|widget):$/,co=/^(?:GET|HEAD)$/,cp=/^\/\//,cq=/\?/,cr=/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,cs=/([?&])_=[^&]*/,ct=/^([\w\+\.\-]+:)(?:\/\/([^\/?#:]*)(?::(\d+)|)|)/,cu=p.fn.load,cv={},cw={},cx=["*/"]+["*"];try{cj=f.href}catch(cy){cj=e.createElement("a"),cj.href="",cj=cj.href}ck=ct.exec(cj.toLowerCase())||[],p.fn.load=function(a,c,d){if(typeof a!="string"&&cu)return cu.apply(this,arguments);if(!this.length)return this;var e,f,g,h=this,i=a.indexOf(" ");return i>=0&&(e=a.slice(i,a.length),a=a.slice(0,i)),p.isFunction(c)?(d=c,c=b):c&&typeof c=="object"&&(f="POST"),p.ajax({url:a,type:f,dataType:"html",data:c,complete:function(a,b){d&&h.each(d,g||[a.responseText,b,a])}}).done(function(a){g=arguments,h.html(e?p("<div>").append(a.replace(cr,"")).find(e):a)}),this},p.each("ajaxStart ajaxStop ajaxComplete ajaxError ajaxSuccess ajaxSend".split(" "),function(a,b){p.fn[b]=function(a){return this.on(b,a)}}),p.each(["get","post"],function(a,c){p[c]=function(a,d,e,f){return p.isFunction(d)&&(f=f||e,e=d,d=b),p.ajax({type:c,url:a,data:d,success:e,dataType:f})}}),p.extend({getScript:function(a,c){return p.get(a,b,c,"script")},getJSON:function(a,b,c){return p.get(a,b,c,"json")},ajaxSetup:function(a,b){return b?cB(a,p.ajaxSettings):(b=a,a=p.ajaxSettings),cB(a,b),a},ajaxSettings:{url:cj,isLocal:cn.test(ck[1]),global:!0,type:"GET",contentType:"application/x-www-form-urlencoded; charset=UTF-8",processData:!0,async:!0,accepts:{xml:"application/xml, text/xml",html:"text/html",text:"text/plain",json:"application/json, text/javascript","*":cx},contents:{xml:/xml/,html:/html/,json:/json/},responseFields:{xml:"responseXML",text:"responseText"},converters:{"* text":a.String,"text html":!0,"text json":p.parseJSON,"text xml":p.parseXML},flatOptions:{context:!0,url:!0}},ajaxPrefilter:cz(cv),ajaxTransport:cz(cw),ajax:function(a,c){function y(a,c,f,i){var k,s,t,u,w,y=c;if(v===2)return;v=2,h&&clearTimeout(h),g=b,e=i||"",x.readyState=a>0?4:0,f&&(u=cC(l,x,f));if(a>=200&&a<300||a===304)l.ifModified&&(w=x.getResponseHeader("Last-Modified"),w&&(p.lastModified[d]=w),w=x.getResponseHeader("Etag"),w&&(p.etag[d]=w)),a===304?(y="notmodified",k=!0):(k=cD(l,u),y=k.state,s=k.data,t=k.error,k=!t);else{t=y;if(!y||a)y="error",a<0&&(a=0)}x.status=a,x.statusText=""+(c||y),k?o.resolveWith(m,[s,y,x]):o.rejectWith(m,[x,y,t]),x.statusCode(r),r=b,j&&n.trigger("ajax"+(k?"Success":"Error"),[x,l,k?s:t]),q.fireWith(m,[x,y]),j&&(n.trigger("ajaxComplete",[x,l]),--p.active||p.event.trigger("ajaxStop"))}typeof a=="object"&&(c=a,a=b),c=c||{};var d,e,f,g,h,i,j,k,l=p.ajaxSetup({},c),m=l.context||l,n=m!==l&&(m.nodeType||m instanceof p)?p(m):p.event,o=p.Deferred(),q=p.Callbacks("once memory"),r=l.statusCode||{},t={},u={},v=0,w="canceled",x={readyState:0,setRequestHeader:function(a,b){if(!v){var c=a.toLowerCase();a=u[c]=u[c]||a,t[a]=b}return this},getAllResponseHeaders:function(){return v===2?e:null},getResponseHeader:function(a){var c;if(v===2){if(!f){f={};while(c=cm.exec(e))f[c[1].toLowerCase()]=c[2]}c=f[a.toLowerCase()]}return c===b?null:c},overrideMimeType:function(a){return v||(l.mimeType=a),this},abort:function(a){return a=a||w,g&&g.abort(a),y(0,a),this}};o.promise(x),x.success=x.done,x.error=x.fail,x.complete=q.add,x.statusCode=function(a){if(a){var b;if(v<2)for(b in a)r[b]=[r[b],a[b]];else b=a[x.status],x.always(b)}return this},l.url=((a||l.url)+"").replace(cl,"").replace(cp,ck[1]+"//"),l.dataTypes=p.trim(l.dataType||"*").toLowerCase().split(s),l.crossDomain==null&&(i=ct.exec(l.url.toLowerCase()),l.crossDomain=!(!i||i[1]==ck[1]&&i[2]==ck[2]&&(i[3]||(i[1]==="http:"?80:443))==(ck[3]||(ck[1]==="http:"?80:443)))),l.data&&l.processData&&typeof l.data!="string"&&(l.data=p.param(l.data,l.traditional)),cA(cv,l,c,x);if(v===2)return x;j=l.global,l.type=l.type.toUpperCase(),l.hasContent=!co.test(l.type),j&&p.active++===0&&p.event.trigger("ajaxStart");if(!l.hasContent){l.data&&(l.url+=(cq.test(l.url)?"&":"?")+l.data,delete l.data),d=l.url;if(l.cache===!1){var z=p.now(),A=l.url.replace(cs,"$1_="+z);l.url=A+(A===l.url?(cq.test(l.url)?"&":"?")+"_="+z:"")}}(l.data&&l.hasContent&&l.contentType!==!1||c.contentType)&&x.setRequestHeader("Content-Type",l.contentType),l.ifModified&&(d=d||l.url,p.lastModified[d]&&x.setRequestHeader("If-Modified-Since",p.lastModified[d]),p.etag[d]&&x.setRequestHeader("If-None-Match",p.etag[d])),x.setRequestHeader("Accept",l.dataTypes[0]&&l.accepts[l.dataTypes[0]]?l.accepts[l.dataTypes[0]]+(l.dataTypes[0]!=="*"?", "+cx+"; q=0.01":""):l.accepts["*"]);for(k in l.headers)x.setRequestHeader(k,l.headers[k]);if(!l.beforeSend||l.beforeSend.call(m,x,l)!==!1&&v!==2){w="abort";for(k in{success:1,error:1,complete:1})x[k](l[k]);g=cA(cw,l,c,x);if(!g)y(-1,"No Transport");else{x.readyState=1,j&&n.trigger("ajaxSend",[x,l]),l.async&&l.timeout>0&&(h=setTimeout(function(){x.abort("timeout")},l.timeout));try{v=1,g.send(t,y)}catch(B){if(v<2)y(-1,B);else throw B}}return x}return x.abort()},active:0,lastModified:{},etag:{}});var cE=[],cF=/\?/,cG=/(=)\?(?=&|$)|\?\?/,cH=p.now();p.ajaxSetup({jsonp:"callback",jsonpCallback:function(){var a=cE.pop()||p.expando+"_"+cH++;return this[a]=!0,a}}),p.ajaxPrefilter("json jsonp",function(c,d,e){var f,g,h,i=c.data,j=c.url,k=c.jsonp!==!1,l=k&&cG.test(j),m=k&&!l&&typeof i=="string"&&!(c.contentType||"").indexOf("application/x-www-form-urlencoded")&&cG.test(i);if(c.dataTypes[0]==="jsonp"||l||m)return f=c.jsonpCallback=p.isFunction(c.jsonpCallback)?c.jsonpCallback():c.jsonpCallback,g=a[f],l?c.url=j.replace(cG,"$1"+f):m?c.data=i.replace(cG,"$1"+f):k&&(c.url+=(cF.test(j)?"&":"?")+c.jsonp+"="+f),c.converters["script json"]=function(){return h||p.error(f+" was not called"),h[0]},c.dataTypes[0]="json",a[f]=function(){h=arguments},e.always(function(){a[f]=g,c[f]&&(c.jsonpCallback=d.jsonpCallback,cE.push(f)),h&&p.isFunction(g)&&g(h[0]),h=g=b}),"script"}),p.ajaxSetup({accepts:{script:"text/javascript, application/javascript, application/ecmascript, application/x-ecmascript"},contents:{script:/javascript|ecmascript/},converters:{"text script":function(a){return p.globalEval(a),a}}}),p.ajaxPrefilter("script",function(a){a.cache===b&&(a.cache=!1),a.crossDomain&&(a.type="GET",a.global=!1)}),p.ajaxTransport("script",function(a){if(a.crossDomain){var c,d=e.head||e.getElementsByTagName("head")[0]||e.documentElement;return{send:function(f,g){c=e.createElement("script"),c.async="async",a.scriptCharset&&(c.charset=a.scriptCharset),c.src=a.url,c.onload=c.onreadystatechange=function(a,e){if(e||!c.readyState||/loaded|complete/.test(c.readyState))c.onload=c.onreadystatechange=null,d&&c.parentNode&&d.removeChild(c),c=b,e||g(200,"success")},d.insertBefore(c,d.firstChild)},abort:function(){c&&c.onload(0,1)}}}});var cI,cJ=a.ActiveXObject?function(){for(var a in cI)cI[a](0,1)}:!1,cK=0;p.ajaxSettings.xhr=a.ActiveXObject?function(){return!this.isLocal&&cL()||cM()}:cL,function(a){p.extend(p.support,{ajax:!!a,cors:!!a&&"withCredentials"in a})}(p.ajaxSettings.xhr()),p.support.ajax&&p.ajaxTransport(function(c){if(!c.crossDomain||p.support.cors){var d;return{send:function(e,f){var g,h,i=c.xhr();c.username?i.open(c.type,c.url,c.async,c.username,c.password):i.open(c.type,c.url,c.async);if(c.xhrFields)for(h in c.xhrFields)i[h]=c.xhrFields[h];c.mimeType&&i.overrideMimeType&&i.overrideMimeType(c.mimeType),!c.crossDomain&&!e["X-Requested-With"]&&(e["X-Requested-With"]="XMLHttpRequest");try{for(h in e)i.setRequestHeader(h,e[h])}catch(j){}i.send(c.hasContent&&c.data||null),d=function(a,e){var h,j,k,l,m;try{if(d&&(e||i.readyState===4)){d=b,g&&(i.onreadystatechange=p.noop,cJ&&delete cI[g]);if(e)i.readyState!==4&&i.abort();else{h=i.status,k=i.getAllResponseHeaders(),l={},m=i.responseXML,m&&m.documentElement&&(l.xml=m);try{l.text=i.responseText}catch(a){}try{j=i.statusText}catch(n){j=""}!h&&c.isLocal&&!c.crossDomain?h=l.text?200:404:h===1223&&(h=204)}}}catch(o){e||f(-1,o)}l&&f(h,j,l,k)},c.async?i.readyState===4?setTimeout(d,0):(g=++cK,cJ&&(cI||(cI={},p(a).unload(cJ)),cI[g]=d),i.onreadystatechange=d):d()},abort:function(){d&&d(0,1)}}}});var cN,cO,cP=/^(?:toggle|show|hide)$/,cQ=new RegExp("^(?:([-+])=|)("+q+")([a-z%]*)$","i"),cR=/queueHooks$/,cS=[cY],cT={"*":[function(a,b){var c,d,e,f=this.createTween(a,b),g=cQ.exec(b),h=f.cur(),i=+h||0,j=1;if(g){c=+g[2],d=g[3]||(p.cssNumber[a]?"":"px");if(d!=="px"&&i){i=p.css(f.elem,a,!0)||c||1;do e=j=j||".5",i=i/j,p.style(f.elem,a,i+d),j=f.cur()/h;while(j!==1&&j!==e)}f.unit=d,f.start=i,f.end=g[1]?i+(g[1]+1)*c:c}return f}]};p.Animation=p.extend(cW,{tweener:function(a,b){p.isFunction(a)?(b=a,a=["*"]):a=a.split(" ");var c,d=0,e=a.length;for(;d<e;d++)c=a[d],cT[c]=cT[c]||[],cT[c].unshift(b)},prefilter:function(a,b){b?cS.unshift(a):cS.push(a)}}),p.Tween=cZ,cZ.prototype={constructor:cZ,init:function(a,b,c,d,e,f){this.elem=a,this.prop=c,this.easing=e||"swing",this.options=b,this.start=this.now=this.cur(),this.end=d,this.unit=f||(p.cssNumber[c]?"":"px")},cur:function(){var a=cZ.propHooks[this.prop];return a&&a.get?a.get(this):cZ.propHooks._default.get(this)},run:function(a){var b,c=cZ.propHooks[this.prop];return this.options.duration?this.pos=b=p.easing[this.easing](a,this.options.duration*a,0,1,this.options.duration):this.pos=b=a,this.now=(this.end-this.start)*b+this.start,this.options.step&&this.options.step.call(this.elem,this.now,this),c&&c.set?c.set(this):cZ.propHooks._default.set(this),this}},cZ.prototype.init.prototype=cZ.prototype,cZ.propHooks={_default:{get:function(a){var b;return a.elem[a.prop]==null||!!a.elem.style&&a.elem.style[a.prop]!=null?(b=p.css(a.elem,a.prop,!1,""),!b||b==="auto"?0:b):a.elem[a.prop]},set:function(a){p.fx.step[a.prop]?p.fx.step[a.prop](a):a.elem.style&&(a.elem.style[p.cssProps[a.prop]]!=null||p.cssHooks[a.prop])?p.style(a.elem,a.prop,a.now+a.unit):a.elem[a.prop]=a.now}}},cZ.propHooks.scrollTop=cZ.propHooks.scrollLeft={set:function(a){a.elem.nodeType&&a.elem.parentNode&&(a.elem[a.prop]=a.now)}},p.each(["toggle","show","hide"],function(a,b){var c=p.fn[b];p.fn[b]=function(d,e,f){return d==null||typeof d=="boolean"||!a&&p.isFunction(d)&&p.isFunction(e)?c.apply(this,arguments):this.animate(c$(b,!0),d,e,f)}}),p.fn.extend({fadeTo:function(a,b,c,d){return this.filter(bZ).css("opacity",0).show().end().animate({opacity:b},a,c,d)},animate:function(a,b,c,d){var e=p.isEmptyObject(a),f=p.speed(b,c,d),g=function(){var b=cW(this,p.extend({},a),f);e&&b.stop(!0)};return e||f.queue===!1?this.each(g):this.queue(f.queue,g)},stop:function(a,c,d){var e=function(a){var b=a.stop;delete a.stop,b(d)};return typeof a!="string"&&(d=c,c=a,a=b),c&&a!==!1&&this.queue(a||"fx",[]),this.each(function(){var b=!0,c=a!=null&&a+"queueHooks",f=p.timers,g=p._data(this);if(c)g[c]&&g[c].stop&&e(g[c]);else for(c in g)g[c]&&g[c].stop&&cR.test(c)&&e(g[c]);for(c=f.length;c--;)f[c].elem===this&&(a==null||f[c].queue===a)&&(f[c].anim.stop(d),b=!1,f.splice(c,1));(b||!d)&&p.dequeue(this,a)})}}),p.each({slideDown:c$("show"),slideUp:c$("hide"),slideToggle:c$("toggle"),fadeIn:{opacity:"show"},fadeOut:{opacity:"hide"},fadeToggle:{opacity:"toggle"}},function(a,b){p.fn[a]=function(a,c,d){return this.animate(b,a,c,d)}}),p.speed=function(a,b,c){var d=a&&typeof a=="object"?p.extend({},a):{complete:c||!c&&b||p.isFunction(a)&&a,duration:a,easing:c&&b||b&&!p.isFunction(b)&&b};d.duration=p.fx.off?0:typeof d.duration=="number"?d.duration:d.duration in p.fx.speeds?p.fx.speeds[d.duration]:p.fx.speeds._default;if(d.queue==null||d.queue===!0)d.queue="fx";return d.old=d.complete,d.complete=function(){p.isFunction(d.old)&&d.old.call(this),d.queue&&p.dequeue(this,d.queue)},d},p.easing={linear:function(a){return a},swing:function(a){return.5-Math.cos(a*Math.PI)/2}},p.timers=[],p.fx=cZ.prototype.init,p.fx.tick=function(){var a,b=p.timers,c=0;for(;c<b.length;c++)a=b[c],!a()&&b[c]===a&&b.splice(c--,1);b.length||p.fx.stop()},p.fx.timer=function(a){a()&&p.timers.push(a)&&!cO&&(cO=setInterval(p.fx.tick,p.fx.interval))},p.fx.interval=13,p.fx.stop=function(){clearInterval(cO),cO=null},p.fx.speeds={slow:600,fast:200,_default:400},p.fx.step={},p.expr&&p.expr.filters&&(p.expr.filters.animated=function(a){return p.grep(p.timers,function(b){return a===b.elem}).length});var c_=/^(?:body|html)$/i;p.fn.offset=function(a){if(arguments.length)return a===b?this:this.each(function(b){p.offset.setOffset(this,a,b)});var c,d,e,f,g,h,i,j,k,l,m=this[0],n=m&&m.ownerDocument;if(!n)return;return(e=n.body)===m?p.offset.bodyOffset(m):(d=n.documentElement,p.contains(d,m)?(c=m.getBoundingClientRect(),f=da(n),g=d.clientTop||e.clientTop||0,h=d.clientLeft||e.clientLeft||0,i=f.pageYOffset||d.scrollTop,j=f.pageXOffset||d.scrollLeft,k=c.top+i-g,l=c.left+j-h,{top:k,left:l}):{top:0,left:0})},p.offset={bodyOffset:function(a){var b=a.offsetTop,c=a.offsetLeft;return p.support.doesNotIncludeMarginInBodyOffset&&(b+=parseFloat(p.css(a,"marginTop"))||0,c+=parseFloat(p.css(a,"marginLeft"))||0),{top:b,left:c}},setOffset:function(a,b,c){var d=p.css(a,"position");d==="static"&&(a.style.position="relative");var e=p(a),f=e.offset(),g=p.css(a,"top"),h=p.css(a,"left"),i=(d==="absolute"||d==="fixed")&&p.inArray("auto",[g,h])>-1,j={},k={},l,m;i?(k=e.position(),l=k.top,m=k.left):(l=parseFloat(g)||0,m=parseFloat(h)||0),p.isFunction(b)&&(b=b.call(a,c,f)),b.top!=null&&(j.top=b.top-f.top+l),b.left!=null&&(j.left=b.left-f.left+m),"using"in b?b.using.call(a,j):e.css(j)}},p.fn.extend({position:function(){if(!this[0])return;var a=this[0],b=this.offsetParent(),c=this.offset(),d=c_.test(b[0].nodeName)?{top:0,left:0}:b.offset();return c.top-=parseFloat(p.css(a,"marginTop"))||0,c.left-=parseFloat(p.css(a,"marginLeft"))||0,d.top+=parseFloat(p.css(b[0],"borderTopWidth"))||0,d.left+=parseFloat(p.css(b[0],"borderLeftWidth"))||0,{top:c.top-d.top,left:c.left-d.left}},offsetParent:function(){return this.map(function(){var a=this.offsetParent||e.body;while(a&&!c_.test(a.nodeName)&&p.css(a,"position")==="static")a=a.offsetParent;return a||e.body})}}),p.each({scrollLeft:"pageXOffset",scrollTop:"pageYOffset"},function(a,c){var d=/Y/.test(c);p.fn[a]=function(e){return p.access(this,function(a,e,f){var g=da(a);if(f===b)return g?c in g?g[c]:g.document.documentElement[e]:a[e];g?g.scrollTo(d?p(g).scrollLeft():f,d?f:p(g).scrollTop()):a[e]=f},a,e,arguments.length,null)}}),p.each({Height:"height",Width:"width"},function(a,c){p.each({padding:"inner"+a,content:c,"":"outer"+a},function(d,e){p.fn[e]=function(e,f){var g=arguments.length&&(d||typeof e!="boolean"),h=d||(e===!0||f===!0?"margin":"border");return p.access(this,function(c,d,e){var f;return p.isWindow(c)?c.document.documentElement["client"+a]:c.nodeType===9?(f=c.documentElement,Math.max(c.body["scroll"+a],f["scroll"+a],c.body["offset"+a],f["offset"+a],f["client"+a])):e===b?p.css(c,d,e,h):p.style(c,d,e,h)},c,g?e:b,g,null)}})}),a.jQuery=a.$=p,typeof define=="function"&&define.amd&&define.amd.jQuery&&define("jquery",[],function(){return p})})(window);'
]

{ #category : #uploads }
OHFileRequestHandler >> jsbootstrapminJs [
	^ '/*!
* Bootstrap.js by @fat & @mdo
* Copyright 2012 Twitter, Inc.
* http://www.apache.org/licenses/LICENSE-2.0.txt
*/
!function($){"use strict";$(function(){$.support.transition=function(){var transitionEnd=function(){var name,el=document.createElement("bootstrap"),transEndEventNames={WebkitTransition:"webkitTransitionEnd",MozTransition:"transitionend",OTransition:"oTransitionEnd otransitionend",transition:"transitionend"};for(name in transEndEventNames)if(void 0!==el.style[name])return transEndEventNames[name]}();return transitionEnd&&{end:transitionEnd}}()})}(window.jQuery),!function($){"use strict";var dismiss=''[data-dismiss="alert"]'',Alert=function(el){$(el).on("click",dismiss,this.close)};Alert.prototype.close=function(e){function removeElement(){$parent.trigger("closed").remove()}var $parent,$this=$(this),selector=$this.attr("data-target");selector||(selector=$this.attr("href"),selector=selector&&selector.replace(/.*(?=#[^\s]*$)/,"")),$parent=$(selector),e&&e.preventDefault(),$parent.length||($parent=$this.hasClass("alert")?$this:$this.parent()),$parent.trigger(e=$.Event("close")),e.isDefaultPrevented()||($parent.removeClass("in"),$.support.transition&&$parent.hasClass("fade")?$parent.on($.support.transition.end,removeElement):removeElement())};var old=$.fn.alert;$.fn.alert=function(option){return this.each(function(){var $this=$(this),data=$this.data("alert");data||$this.data("alert",data=new Alert(this)),"string"==typeof option&&data[option].call($this)})},$.fn.alert.Constructor=Alert,$.fn.alert.noConflict=function(){return $.fn.alert=old,this},$(document).on("click.alert.data-api",dismiss,Alert.prototype.close)}(window.jQuery),!function($){"use strict";var Button=function(element,options){this.$element=$(element),this.options=$.extend({},$.fn.button.defaults,options)};Button.prototype.setState=function(state){var d="disabled",$el=this.$element,data=$el.data(),val=$el.is("input")?"val":"html";state+="Text",data.resetText||$el.data("resetText",$el[val]()),$el[val](data[state]||this.options[state]),setTimeout(function(){"loadingText"==state?$el.addClass(d).attr(d,d):$el.removeClass(d).removeAttr(d)},0)},Button.prototype.toggle=function(){var $parent=this.$element.closest(''[data-toggle="buttons-radio"]'');$parent&&$parent.find(".active").removeClass("active"),this.$element.toggleClass("active")};var old=$.fn.button;$.fn.button=function(option){return this.each(function(){var $this=$(this),data=$this.data("button"),options="object"==typeof option&&option;data||$this.data("button",data=new Button(this,options)),"toggle"==option?data.toggle():option&&data.setState(option)})},$.fn.button.defaults={loadingText:"loading..."},$.fn.button.Constructor=Button,$.fn.button.noConflict=function(){return $.fn.button=old,this},$(document).on("click.button.data-api","[data-toggle^=button]",function(e){var $btn=$(e.target);$btn.hasClass("btn")||($btn=$btn.closest(".btn")),$btn.button("toggle")})}(window.jQuery),!function($){"use strict";var Carousel=function(element,options){this.$element=$(element),this.options=options,"hover"==this.options.pause&&this.$element.on("mouseenter",$.proxy(this.pause,this)).on("mouseleave",$.proxy(this.cycle,this))};Carousel.prototype={cycle:function(e){return e||(this.paused=!1),this.options.interval&&!this.paused&&(this.interval=setInterval($.proxy(this.next,this),this.options.interval)),this},to:function(pos){var $active=this.$element.find(".item.active"),children=$active.parent().children(),activePos=children.index($active),that=this;if(!(pos>children.length-1||0>pos))return this.sliding?this.$element.one("slid",function(){that.to(pos)}):activePos==pos?this.pause().cycle():this.slide(pos>activePos?"next":"prev",$(children[pos]))},pause:function(e){return e||(this.paused=!0),this.$element.find(".next, .prev").length&&$.support.transition.end&&(this.$element.trigger($.support.transition.end),this.cycle()),clearInterval(this.interval),this.interval=null,this},next:function(){return this.sliding?void 0:this.slide("next")},prev:function(){return this.sliding?void 0:this.slide("prev")},slide:function(type,next){var e,$active=this.$element.find(".item.active"),$next=next||$active[type](),isCycling=this.interval,direction="next"==type?"left":"right",fallback="next"==type?"first":"last",that=this;if(this.sliding=!0,isCycling&&this.pause(),$next=$next.length?$next:this.$element.find(".item")[fallback](),e=$.Event("slide",{relatedTarget:$next[0]}),!$next.hasClass("active")){if($.support.transition&&this.$element.hasClass("slide")){if(this.$element.trigger(e),e.isDefaultPrevented())return;$next.addClass(type),$next[0].offsetWidth,$active.addClass(direction),$next.addClass(direction),this.$element.one($.support.transition.end,function(){$next.removeClass([type,direction].join(" ")).addClass("active"),$active.removeClass(["active",direction].join(" ")),that.sliding=!1,setTimeout(function(){that.$element.trigger("slid")},0)})}else{if(this.$element.trigger(e),e.isDefaultPrevented())return;$active.removeClass("active"),$next.addClass("active"),this.sliding=!1,this.$element.trigger("slid")}return isCycling&&this.cycle(),this}}};var old=$.fn.carousel;$.fn.carousel=function(option){return this.each(function(){var $this=$(this),data=$this.data("carousel"),options=$.extend({},$.fn.carousel.defaults,"object"==typeof option&&option),action="string"==typeof option?option:options.slide;data||$this.data("carousel",data=new Carousel(this,options)),"number"==typeof option?data.to(option):action?data[action]():options.interval&&data.cycle()})},$.fn.carousel.defaults={interval:5e3,pause:"hover"},$.fn.carousel.Constructor=Carousel,$.fn.carousel.noConflict=function(){return $.fn.carousel=old,this},$(document).on("click.carousel.data-api","[data-slide]",function(e){var href,$this=$(this),$target=$($this.attr("data-target")||(href=$this.attr("href"))&&href.replace(/.*(?=#[^\s]+$)/,"")),options=$.extend({},$target.data(),$this.data());$target.carousel(options),e.preventDefault()})}(window.jQuery),!function($){"use strict";var Collapse=function(element,options){this.$element=$(element),this.options=$.extend({},$.fn.collapse.defaults,options),this.options.parent&&(this.$parent=$(this.options.parent)),this.options.toggle&&this.toggle()};Collapse.prototype={constructor:Collapse,dimension:function(){var hasWidth=this.$element.hasClass("width");return hasWidth?"width":"height"},show:function(){var dimension,scroll,actives,hasData;if(!this.transitioning){if(dimension=this.dimension(),scroll=$.camelCase(["scroll",dimension].join("-")),actives=this.$parent&&this.$parent.find("> .accordion-group > .in"),actives&&actives.length){if(hasData=actives.data("collapse"),hasData&&hasData.transitioning)return;actives.collapse("hide"),hasData||actives.data("collapse",null)}this.$element[dimension](0),this.transition("addClass",$.Event("show"),"shown"),$.support.transition&&this.$element[dimension](this.$element[0][scroll])}},hide:function(){var dimension;this.transitioning||(dimension=this.dimension(),this.reset(this.$element[dimension]()),this.transition("removeClass",$.Event("hide"),"hidden"),this.$element[dimension](0))},reset:function(size){var dimension=this.dimension();return this.$element.removeClass("collapse")[dimension](size||"auto")[0].offsetWidth,this.$element[null!==size?"addClass":"removeClass"]("collapse"),this},transition:function(method,startEvent,completeEvent){var that=this,complete=function(){"show"==startEvent.type&&that.reset(),that.transitioning=0,that.$element.trigger(completeEvent)};this.$element.trigger(startEvent),startEvent.isDefaultPrevented()||(this.transitioning=1,this.$element[method]("in"),$.support.transition&&this.$element.hasClass("collapse")?this.$element.one($.support.transition.end,complete):complete())},toggle:function(){this[this.$element.hasClass("in")?"hide":"show"]()}};var old=$.fn.collapse;$.fn.collapse=function(option){return this.each(function(){var $this=$(this),data=$this.data("collapse"),options="object"==typeof option&&option;data||$this.data("collapse",data=new Collapse(this,options)),"string"==typeof option&&data[option]()})},$.fn.collapse.defaults={toggle:!0},$.fn.collapse.Constructor=Collapse,$.fn.collapse.noConflict=function(){return $.fn.collapse=old,this},$(document).on("click.collapse.data-api","[data-toggle=collapse]",function(e){var href,$this=$(this),target=$this.attr("data-target")||e.preventDefault()||(href=$this.attr("href"))&&href.replace(/.*(?=#[^\s]+$)/,""),option=$(target).data("collapse")?"toggle":$this.data();$this[$(target).hasClass("in")?"addClass":"removeClass"]("collapsed"),$(target).collapse(option)})}(window.jQuery),!function($){"use strict";function clearMenus(){$(toggle).each(function(){getParent($(this)).removeClass("open")})}function getParent($this){var $parent,selector=$this.attr("data-target");return selector||(selector=$this.attr("href"),selector=selector&&/#/.test(selector)&&selector.replace(/.*(?=#[^\s]*$)/,"")),$parent=$(selector),$parent.length||($parent=$this.parent()),$parent}var toggle="[data-toggle=dropdown]",Dropdown=function(element){var $el=$(element).on("click.dropdown.data-api",this.toggle);$("html").on("click.dropdown.data-api",function(){$el.parent().removeClass("open")})};Dropdown.prototype={constructor:Dropdown,toggle:function(){var $parent,isActive,$this=$(this);if(!$this.is(".disabled, :disabled"))return $parent=getParent($this),isActive=$parent.hasClass("open"),clearMenus(),isActive||$parent.toggleClass("open"),$this.focus(),!1},keydown:function(e){var $this,$items,$parent,isActive,index;if(/(38|40|27)/.test(e.keyCode)&&($this=$(this),e.preventDefault(),e.stopPropagation(),!$this.is(".disabled, :disabled"))){if($parent=getParent($this),isActive=$parent.hasClass("open"),!isActive||isActive&&27==e.keyCode)return $this.click();$items=$("[role=menu] li:not(.divider):visible a",$parent),$items.length&&(index=$items.index($items.filter(":focus")),38==e.keyCode&&index>0&&index--,40==e.keyCode&&$items.length-1>index&&index++,~index||(index=0),$items.eq(index).focus())}}};var old=$.fn.dropdown;$.fn.dropdown=function(option){return this.each(function(){var $this=$(this),data=$this.data("dropdown");data||$this.data("dropdown",data=new Dropdown(this)),"string"==typeof option&&data[option].call($this)})},$.fn.dropdown.Constructor=Dropdown,$.fn.dropdown.noConflict=function(){return $.fn.dropdown=old,this},$(document).on("click.dropdown.data-api touchstart.dropdown.data-api",clearMenus).on("click.dropdown touchstart.dropdown.data-api",".dropdown form",function(e){e.stopPropagation()}).on("touchstart.dropdown.data-api",".dropdown-menu",function(e){e.stopPropagation()}).on("click.dropdown.data-api touchstart.dropdown.data-api",toggle,Dropdown.prototype.toggle).on("keydown.dropdown.data-api touchstart.dropdown.data-api",toggle+", [role=menu]",Dropdown.prototype.keydown)}(window.jQuery),!function($){"use strict";var Modal=function(element,options){this.options=options,this.$element=$(element).delegate(''[data-dismiss="modal"]'',"click.dismiss.modal",$.proxy(this.hide,this)),this.options.remote&&this.$element.find(".modal-body").load(this.options.remote)};Modal.prototype={constructor:Modal,toggle:function(){return this[this.isShown?"hide":"show"]()},show:function(){var that=this,e=$.Event("show");this.$element.trigger(e),this.isShown||e.isDefaultPrevented()||(this.isShown=!0,this.escape(),this.backdrop(function(){var transition=$.support.transition&&that.$element.hasClass("fade");that.$element.parent().length||that.$element.appendTo(document.body),that.$element.show(),transition&&that.$element[0].offsetWidth,that.$element.addClass("in").attr("aria-hidden",!1),that.enforceFocus(),transition?that.$element.one($.support.transition.end,function(){that.$element.focus().trigger("shown")}):that.$element.focus().trigger("shown")}))},hide:function(e){e&&e.preventDefault(),e=$.Event("hide"),this.$element.trigger(e),this.isShown&&!e.isDefaultPrevented()&&(this.isShown=!1,this.escape(),$(document).off("focusin.modal"),this.$element.removeClass("in").attr("aria-hidden",!0),$.support.transition&&this.$element.hasClass("fade")?this.hideWithTransition():this.hideModal())},enforceFocus:function(){var that=this;$(document).on("focusin.modal",function(e){that.$element[0]===e.target||that.$element.has(e.target).length||that.$element.focus()})},escape:function(){var that=this;this.isShown&&this.options.keyboard?this.$element.on("keyup.dismiss.modal",function(e){27==e.which&&that.hide()}):this.isShown||this.$element.off("keyup.dismiss.modal")},hideWithTransition:function(){var that=this,timeout=setTimeout(function(){that.$element.off($.support.transition.end),that.hideModal()},500);this.$element.one($.support.transition.end,function(){clearTimeout(timeout),that.hideModal()})},hideModal:function(){this.$element.hide().trigger("hidden"),this.backdrop()},removeBackdrop:function(){this.$backdrop.remove(),this.$backdrop=null},backdrop:function(callback){var animate=this.$element.hasClass("fade")?"fade":"";if(this.isShown&&this.options.backdrop){var doAnimate=$.support.transition&&animate;this.$backdrop=$(''<div class="modal-backdrop ''+animate+''" />'').appendTo(document.body),this.$backdrop.click("static"==this.options.backdrop?$.proxy(this.$element[0].focus,this.$element[0]):$.proxy(this.hide,this)),doAnimate&&this.$backdrop[0].offsetWidth,this.$backdrop.addClass("in"),doAnimate?this.$backdrop.one($.support.transition.end,callback):callback()}else!this.isShown&&this.$backdrop?(this.$backdrop.removeClass("in"),$.support.transition&&this.$element.hasClass("fade")?this.$backdrop.one($.support.transition.end,$.proxy(this.removeBackdrop,this)):this.removeBackdrop()):callback&&callback()}};var old=$.fn.modal;$.fn.modal=function(option){return this.each(function(){var $this=$(this),data=$this.data("modal"),options=$.extend({},$.fn.modal.defaults,$this.data(),"object"==typeof option&&option);data||$this.data("modal",data=new Modal(this,options)),"string"==typeof option?data[option]():options.show&&data.show()})},$.fn.modal.defaults={backdrop:!0,keyboard:!0,show:!0},$.fn.modal.Constructor=Modal,$.fn.modal.noConflict=function(){return $.fn.modal=old,this},$(document).on("click.modal.data-api",''[data-toggle="modal"]'',function(e){var $this=$(this),href=$this.attr("href"),$target=$($this.attr("data-target")||href&&href.replace(/.*(?=#[^\s]+$)/,"")),option=$target.data("modal")?"toggle":$.extend({remote:!/#/.test(href)&&href},$target.data(),$this.data());e.preventDefault(),$target.modal(option).one("hide",function(){$this.focus()})})}(window.jQuery),!function($){"use strict";var Tooltip=function(element,options){this.init("tooltip",element,options)};Tooltip.prototype={constructor:Tooltip,init:function(type,element,options){var eventIn,eventOut;this.type=type,this.$element=$(element),this.options=this.getOptions(options),this.enabled=!0,"click"==this.options.trigger?this.$element.on("click."+this.type,this.options.selector,$.proxy(this.toggle,this)):"manual"!=this.options.trigger&&(eventIn="hover"==this.options.trigger?"mouseenter":"focus",eventOut="hover"==this.options.trigger?"mouseleave":"blur",this.$element.on(eventIn+"."+this.type,this.options.selector,$.proxy(this.enter,this)),this.$element.on(eventOut+"."+this.type,this.options.selector,$.proxy(this.leave,this))),this.options.selector?this._options=$.extend({},this.options,{trigger:"manual",selector:""}):this.fixTitle()},getOptions:function(options){return options=$.extend({},$.fn[this.type].defaults,options,this.$element.data()),options.delay&&"number"==typeof options.delay&&(options.delay={show:options.delay,hide:options.delay}),options},enter:function(e){var self=$(e.currentTarget)[this.type](this._options).data(this.type);return self.options.delay&&self.options.delay.show?(clearTimeout(this.timeout),self.hoverState="in",this.timeout=setTimeout(function(){"in"==self.hoverState&&self.show()},self.options.delay.show),void 0):self.show()},leave:function(e){var self=$(e.currentTarget)[this.type](this._options).data(this.type);return this.timeout&&clearTimeout(this.timeout),self.options.delay&&self.options.delay.hide?(self.hoverState="out",this.timeout=setTimeout(function(){"out"==self.hoverState&&self.hide()},self.options.delay.hide),void 0):self.hide()},show:function(){var $tip,inside,pos,actualWidth,actualHeight,placement,tp;if(this.hasContent()&&this.enabled){switch($tip=this.tip(),this.setContent(),this.options.animation&&$tip.addClass("fade"),placement="function"==typeof this.options.placement?this.options.placement.call(this,$tip[0],this.$element[0]):this.options.placement,inside=/in/.test(placement),$tip.detach().css({top:0,left:0,display:"block"}).insertAfter(this.$element),pos=this.getPosition(inside),actualWidth=$tip[0].offsetWidth,actualHeight=$tip[0].offsetHeight,inside?placement.split(" ")[1]:placement){case"bottom":tp={top:pos.top+pos.height,left:pos.left+pos.width/2-actualWidth/2};break;case"top":tp={top:pos.top-actualHeight,left:pos.left+pos.width/2-actualWidth/2};break;case"left":tp={top:pos.top+pos.height/2-actualHeight/2,left:pos.left-actualWidth};break;case"right":tp={top:pos.top+pos.height/2-actualHeight/2,left:pos.left+pos.width}}$tip.offset(tp).addClass(placement).addClass("in")}},setContent:function(){var $tip=this.tip(),title=this.getTitle();$tip.find(".tooltip-inner")[this.options.html?"html":"text"](title),$tip.removeClass("fade in top bottom left right")},hide:function(){function removeWithAnimation(){var timeout=setTimeout(function(){$tip.off($.support.transition.end).detach()},500);$tip.one($.support.transition.end,function(){clearTimeout(timeout),$tip.detach()})}var $tip=this.tip();return $tip.removeClass("in"),$.support.transition&&this.$tip.hasClass("fade")?removeWithAnimation():$tip.detach(),this},fixTitle:function(){var $e=this.$element;($e.attr("title")||"string"!=typeof $e.attr("data-original-title"))&&$e.attr("data-original-title",$e.attr("title")||"").removeAttr("title")},hasContent:function(){return this.getTitle()},getPosition:function(inside){return $.extend({},inside?{top:0,left:0}:this.$element.offset(),{width:this.$element[0].offsetWidth,height:this.$element[0].offsetHeight})},getTitle:function(){var title,$e=this.$element,o=this.options;return title=$e.attr("data-original-title")||("function"==typeof o.title?o.title.call($e[0]):o.title)},tip:function(){return this.$tip=this.$tip||$(this.options.template)},validate:function(){this.$element[0].parentNode||(this.hide(),this.$element=null,this.options=null)},enable:function(){this.enabled=!0},disable:function(){this.enabled=!1},toggleEnabled:function(){this.enabled=!this.enabled},toggle:function(e){var self=$(e.currentTarget)[this.type](this._options).data(this.type);self[self.tip().hasClass("in")?"hide":"show"]()},destroy:function(){this.hide().$element.off("."+this.type).removeData(this.type)}};var old=$.fn.tooltip;$.fn.tooltip=function(option){return this.each(function(){var $this=$(this),data=$this.data("tooltip"),options="object"==typeof option&&option;data||$this.data("tooltip",data=new Tooltip(this,options)),"string"==typeof option&&data[option]()})},$.fn.tooltip.Constructor=Tooltip,$.fn.tooltip.defaults={animation:!0,placement:"top",selector:!1,template:''<div class="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>'',trigger:"hover",title:"",delay:0,html:!1},$.fn.tooltip.noConflict=function(){return $.fn.tooltip=old,this}}(window.jQuery),!function($){"use strict";var Popover=function(element,options){this.init("popover",element,options)};Popover.prototype=$.extend({},$.fn.tooltip.Constructor.prototype,{constructor:Popover,setContent:function(){var $tip=this.tip(),title=this.getTitle(),content=this.getContent();$tip.find(".popover-title")[this.options.html?"html":"text"](title),$tip.find(".popover-content")[this.options.html?"html":"text"](content),$tip.removeClass("fade top bottom left right in")},hasContent:function(){return this.getTitle()||this.getContent()},getContent:function(){var content,$e=this.$element,o=this.options;return content=$e.attr("data-content")||("function"==typeof o.content?o.content.call($e[0]):o.content)},tip:function(){return this.$tip||(this.$tip=$(this.options.template)),this.$tip},destroy:function(){this.hide().$element.off("."+this.type).removeData(this.type)}});var old=$.fn.popover;$.fn.popover=function(option){return this.each(function(){var $this=$(this),data=$this.data("popover"),options="object"==typeof option&&option;data||$this.data("popover",data=new Popover(this,options)),"string"==typeof option&&data[option]()})},$.fn.popover.Constructor=Popover,$.fn.popover.defaults=$.extend({},$.fn.tooltip.defaults,{placement:"right",trigger:"click",content:"",template:''<div class="popover"><div class="arrow"></div><div class="popover-inner"><h3 class="popover-title"></h3><div class="popover-content"></div></div></div>''}),$.fn.popover.noConflict=function(){return $.fn.popover=old,this}}(window.jQuery),!function($){"use strict";function ScrollSpy(element,options){var href,process=$.proxy(this.process,this),$element=$(element).is("body")?$(window):$(element);this.options=$.extend({},$.fn.scrollspy.defaults,options),this.$scrollElement=$element.on("scroll.scroll-spy.data-api",process),this.selector=(this.options.target||(href=$(element).attr("href"))&&href.replace(/.*(?=#[^\s]+$)/,"")||"")+" .nav li > a",this.$body=$("body"),this.refresh(),this.process()}ScrollSpy.prototype={constructor:ScrollSpy,refresh:function(){var $targets,self=this;this.offsets=$([]),this.targets=$([]),$targets=this.$body.find(this.selector).map(function(){var $el=$(this),href=$el.data("target")||$el.attr("href"),$href=/^#\w/.test(href)&&$(href);return $href&&$href.length&&[[$href.position().top+self.$scrollElement.scrollTop(),href]]||null}).sort(function(a,b){return a[0]-b[0]}).each(function(){self.offsets.push(this[0]),self.targets.push(this[1])})},process:function(){var i,scrollTop=this.$scrollElement.scrollTop()+this.options.offset,scrollHeight=this.$scrollElement[0].scrollHeight||this.$body[0].scrollHeight,maxScroll=scrollHeight-this.$scrollElement.height(),offsets=this.offsets,targets=this.targets,activeTarget=this.activeTarget;if(scrollTop>=maxScroll)return activeTarget!=(i=targets.last()[0])&&this.activate(i);for(i=offsets.length;i--;)activeTarget!=targets[i]&&scrollTop>=offsets[i]&&(!offsets[i+1]||offsets[i+1]>=scrollTop)&&this.activate(targets[i])},activate:function(target){var active,selector;this.activeTarget=target,$(this.selector).parent(".active").removeClass("active"),selector=this.selector+''[data-target="''+target+''"],''+this.selector+''[href="''+target+''"]'',active=$(selector).parent("li").addClass("active"),active.parent(".dropdown-menu").length&&(active=active.closest("li.dropdown").addClass("active")),active.trigger("activate")}};var old=$.fn.scrollspy;$.fn.scrollspy=function(option){return this.each(function(){var $this=$(this),data=$this.data("scrollspy"),options="object"==typeof option&&option;data||$this.data("scrollspy",data=new ScrollSpy(this,options)),"string"==typeof option&&data[option]()})},$.fn.scrollspy.Constructor=ScrollSpy,$.fn.scrollspy.defaults={offset:10},$.fn.scrollspy.noConflict=function(){return $.fn.scrollspy=old,this},$(window).on("load",function(){$(''[data-spy="scroll"]'').each(function(){var $spy=$(this);$spy.scrollspy($spy.data())})})}(window.jQuery),!function($){"use strict";var Tab=function(element){this.element=$(element)};Tab.prototype={constructor:Tab,show:function(){var previous,$target,e,$this=this.element,$ul=$this.closest("ul:not(.dropdown-menu)"),selector=$this.attr("data-target");selector||(selector=$this.attr("href"),selector=selector&&selector.replace(/.*(?=#[^\s]*$)/,"")),$this.parent("li").hasClass("active")||(previous=$ul.find(".active:last a")[0],e=$.Event("show",{relatedTarget:previous}),$this.trigger(e),e.isDefaultPrevented()||($target=$(selector),this.activate($this.parent("li"),$ul),this.activate($target,$target.parent(),function(){$this.trigger({type:"shown",relatedTarget:previous})})))},activate:function(element,container,callback){function next(){$active.removeClass("active").find("> .dropdown-menu > .active").removeClass("active"),element.addClass("active"),transition?(element[0].offsetWidth,element.addClass("in")):element.removeClass("fade"),element.parent(".dropdown-menu")&&element.closest("li.dropdown").addClass("active"),callback&&callback()}var $active=container.find("> .active"),transition=callback&&$.support.transition&&$active.hasClass("fade");transition?$active.one($.support.transition.end,next):next(),$active.removeClass("in")}};var old=$.fn.tab;$.fn.tab=function(option){return this.each(function(){var $this=$(this),data=$this.data("tab");data||$this.data("tab",data=new Tab(this)),"string"==typeof option&&data[option]()})},$.fn.tab.Constructor=Tab,$.fn.tab.noConflict=function(){return $.fn.tab=old,this},$(document).on("click.tab.data-api",''[data-toggle="tab"], [data-toggle="pill"]'',function(e){e.preventDefault(),$(this).tab("show")})}(window.jQuery),!function($){"use strict";var Typeahead=function(element,options){this.$element=$(element),this.options=$.extend({},$.fn.typeahead.defaults,options),this.matcher=this.options.matcher||this.matcher,this.sorter=this.options.sorter||this.sorter,this.highlighter=this.options.highlighter||this.highlighter,this.updater=this.options.updater||this.updater,this.source=this.options.source,this.$menu=$(this.options.menu),this.shown=!1,this.listen()};Typeahead.prototype={constructor:Typeahead,select:function(){var val=this.$menu.find(".active").attr("data-value");return this.$element.val(this.updater(val)).change(),this.hide()},updater:function(item){return item},show:function(){var pos=$.extend({},this.$element.position(),{height:this.$element[0].offsetHeight});return this.$menu.insertAfter(this.$element).css({top:pos.top+pos.height,left:pos.left}).show(),this.shown=!0,this},hide:function(){return this.$menu.hide(),this.shown=!1,this},lookup:function(){var items;return this.query=this.$element.val(),!this.query||this.query.length<this.options.minLength?this.shown?this.hide():this:(items=$.isFunction(this.source)?this.source(this.query,$.proxy(this.process,this)):this.source,items?this.process(items):this)},process:function(items){var that=this;return items=$.grep(items,function(item){return that.matcher(item)}),items=this.sorter(items),items.length?this.render(items.slice(0,this.options.items)).show():this.shown?this.hide():this},matcher:function(item){return~item.toLowerCase().indexOf(this.query.toLowerCase())},sorter:function(items){for(var item,beginswith=[],caseSensitive=[],caseInsensitive=[];item=items.shift();)item.toLowerCase().indexOf(this.query.toLowerCase())?~item.indexOf(this.query)?caseSensitive.push(item):caseInsensitive.push(item):beginswith.push(item);return beginswith.concat(caseSensitive,caseInsensitive)},highlighter:function(item){var query=this.query.replace(/[\-\[\]{}()*+?.,\\\^$|#\s]/g,"\\$&");return item.replace(RegExp("("+query+")","ig"),function($1,match){return"<strong>"+match+"</strong>"})},render:function(items){var that=this;return items=$(items).map(function(i,item){return i=$(that.options.item).attr("data-value",item),i.find("a").html(that.highlighter(item)),i[0]}),items.first().addClass("active"),this.$menu.html(items),this},next:function(){var active=this.$menu.find(".active").removeClass("active"),next=active.next();next.length||(next=$(this.$menu.find("li")[0])),next.addClass("active")},prev:function(){var active=this.$menu.find(".active").removeClass("active"),prev=active.prev();prev.length||(prev=this.$menu.find("li").last()),prev.addClass("active")},listen:function(){this.$element.on("blur",$.proxy(this.blur,this)).on("keypress",$.proxy(this.keypress,this)).on("keyup",$.proxy(this.keyup,this)),this.eventSupported("keydown")&&this.$element.on("keydown",$.proxy(this.keydown,this)),this.$menu.on("click",$.proxy(this.click,this)).on("mouseenter","li",$.proxy(this.mouseenter,this))},eventSupported:function(eventName){var isSupported=eventName in this.$element;return isSupported||(this.$element.setAttribute(eventName,"return;"),isSupported="function"==typeof this.$element[eventName]),isSupported},move:function(e){if(this.shown){switch(e.keyCode){case 9:case 13:case 27:e.preventDefault();break;case 38:e.preventDefault(),this.prev();break;case 40:e.preventDefault(),this.next()}e.stopPropagation()}},keydown:function(e){this.suppressKeyPressRepeat=~$.inArray(e.keyCode,[40,38,9,13,27]),this.move(e)},keypress:function(e){this.suppressKeyPressRepeat||this.move(e)},keyup:function(e){switch(e.keyCode){case 40:case 38:case 16:case 17:case 18:break;case 9:case 13:if(!this.shown)return;this.select();break;case 27:if(!this.shown)return;this.hide();break;default:this.lookup()}e.stopPropagation(),e.preventDefault()},blur:function(){var that=this;setTimeout(function(){that.hide()},150)},click:function(e){e.stopPropagation(),e.preventDefault(),this.select()},mouseenter:function(e){this.$menu.find(".active").removeClass("active"),$(e.currentTarget).addClass("active")}};var old=$.fn.typeahead;$.fn.typeahead=function(option){return this.each(function(){var $this=$(this),data=$this.data("typeahead"),options="object"==typeof option&&option;data||$this.data("typeahead",data=new Typeahead(this,options)),"string"==typeof option&&data[option]()})},$.fn.typeahead.defaults={source:[],items:8,menu:''<ul class="typeahead dropdown-menu"></ul>'',item:''<li><a href="#"></a></li>'',minLength:1},$.fn.typeahead.Constructor=Typeahead,$.fn.typeahead.noConflict=function(){return $.fn.typeahead=old,this},$(document).on("focus.typeahead.data-api",''[data-provide="typeahead"]'',function(e){var $this=$(this);$this.data("typeahead")||(e.preventDefault(),$this.typeahead($this.data()))})}(window.jQuery),!function($){"use strict";var Affix=function(element,options){this.options=$.extend({},$.fn.affix.defaults,options),this.$window=$(window).on("scroll.affix.data-api",$.proxy(this.checkPosition,this)).on("click.affix.data-api",$.proxy(function(){setTimeout($.proxy(this.checkPosition,this),1)},this)),this.$element=$(element),this.checkPosition()};Affix.prototype.checkPosition=function(){if(this.$element.is(":visible")){var affix,scrollHeight=$(document).height(),scrollTop=this.$window.scrollTop(),position=this.$element.offset(),offset=this.options.offset,offsetBottom=offset.bottom,offsetTop=offset.top,reset="affix affix-top affix-bottom";"object"!=typeof offset&&(offsetBottom=offsetTop=offset),"function"==typeof offsetTop&&(offsetTop=offset.top()),"function"==typeof offsetBottom&&(offsetBottom=offset.bottom()),affix=null!=this.unpin&&scrollTop+this.unpin<=position.top?!1:null!=offsetBottom&&position.top+this.$element.height()>=scrollHeight-offsetBottom?"bottom":null!=offsetTop&&offsetTop>=scrollTop?"top":!1,this.affixed!==affix&&(this.affixed=affix,this.unpin="bottom"==affix?position.top-scrollTop:null,this.$element.removeClass(reset).addClass("affix"+(affix?"-"+affix:"")))}};var old=$.fn.affix;$.fn.affix=function(option){return this.each(function(){var $this=$(this),data=$this.data("affix"),options="object"==typeof option&&option;data||$this.data("affix",data=new Affix(this,options)),"string"==typeof option&&data[option]()})},$.fn.affix.Constructor=Affix,$.fn.affix.defaults={offset:0},$.fn.affix.noConflict=function(){return $.fn.affix=old,this},$(window).on("load",function(){$(''[data-spy="affix"]'').each(function(){var $spy=$(this),data=$spy.data();data.offset=data.offset||{},data.offsetBottom&&(data.offset.bottom=data.offsetBottom),data.offsetTop&&(data.offset.top=data.offsetTop),$spy.affix(data)})})}(window.jQuery);'
]

{ #category : #uploads }
OHFileRequestHandler >> pharoPngContent [
	^ #(137 80 78 71 13 10 26 10 0 0 0 13 73 72 68 82 0 0 0 16 0 0 0 16 8 6 0 0 0 31 243 255 97 0 0 1 179 73 68 65 84 120 218 99 100 32 2 116 175 56 248 255 225 163 43 12 124 2 210 12 109 105 1 140 200 114 140 196 24 176 100 214 172 255 209 206 28 12 183 206 63 103 120 169 28 198 96 103 168 200 72 180 1 71 206 221 251 255 104 233 76 6 237 95 15 24 94 255 100 101 120 236 156 204 144 24 238 72 188 1 171 119 156 249 255 182 50 150 129 139 241 31 3 195 255 127 12 95 178 251 24 178 82 124 137 51 224 208 217 59 255 247 109 217 195 192 177 105 58 131 192 191 31 12 111 63 124 98 248 31 90 192 96 234 235 197 224 110 171 203 72 208 128 29 71 174 254 223 80 83 193 32 249 226 42 195 63 54 14 134 239 47 30 51 252 86 53 99 112 107 159 192 224 105 71 132 1 32 176 118 207 197 255 187 27 74 25 254 63 187 195 240 83 203 150 193 51 59 151 33 220 211 132 248 48 104 157 186 225 255 133 77 171 25 116 60 253 25 188 92 44 24 76 117 228 72 139 198 198 217 187 254 27 169 73 49 232 171 74 49 28 185 112 151 225 226 189 151 12 157 57 62 196 187 0 28 22 199 110 252 95 189 253 36 195 197 35 135 25 20 180 117 24 214 76 41 32 222 128 254 229 71 254 207 95 127 148 225 223 143 175 12 6 186 202 12 153 33 182 12 214 134 74 196 27 160 147 189 242 191 154 16 51 67 164 131 26 67 168 179 30 134 122 188 6 236 63 123 239 255 185 123 111 24 138 67 205 224 234 178 166 29 250 239 103 44 201 224 97 174 74 92 52 194 64 215 154 211 255 215 63 252 203 240 232 31 15 67 135 33 3 67 172 139 14 113 6 244 109 186 240 127 249 43 86 134 71 28 66 12 12 127 254 50 232 125 127 201 176 59 211 152 184 48 168 91 123 225 255 76 6 89 6 198 31 63 24 116 127 188 102 240 22 249 199 80 224 111 132 162 7 0 39 251 160 17 85 34 152 62 0 0 0 0 73 69 78 68 174 66 96 130) asByteArray
]

{ #category : #defaults }
OHFileRequestHandler >> prefix [
	^'files'
]
