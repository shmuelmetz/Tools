/* Developed with AI assistance from Claude (Anthropic) -- 24 Oct 2026 */
/* groupsio2mbox.rex -- convert groups.io message JSON to mbox

   Usage: rexx groupsio2mbox.rex file.json [file.json ...]

   Each file.json is what the groups.io API's getmessages call returns,
   gathered into one object: {"group": name, "fetched": ISO time,
   "me": user ID, "topics": [...], "messages": [...]}. The script
   writes file.mbox beside it, one message per entry, in file order.

   What is reconstructed: groups.io gives a member the messages' text
   and metadata but not the original mail (no raw source, no sender
   addresses, no Message-IDs), so these headers are made up and marked
   by the reserved .invalid top-level domain (RFC 2606 section 2):
     From:        "display name" <user-ID@groups.io.invalid>
     Message-ID:  <message-ID@group.groups.io.invalid>
     In-Reply-To, References: the topic's first message, because the
                  API names a reply's topic but not its parent.
   Everything else comes from the JSON: Date (from "created"), Subject
   ("subject_with_tags", as the list sent it), the body, and the
   X-Groupsio-* headers (message, topic and user IDs, message number,
   hashtags, attachment names and download URLs).

   Formats:
     mbox: the "mboxrd" variant (RFC 4155 and its appendix); a body line
       that starts with "From " or ">From " has its first character
       encoded (=46 or =3E) instead of quoted with ">", which needs no
       unquoting and works with mboxo and mboxrd readers alike.
     Headers: raw UTF-8 (RFC 6532), not RFC 2047 encoded words, which
       would mean splitting UTF-8 subjects at character boundaries.
     Bodies: groups.io stores every body as HTML, plain-text posts
       included, so each is text/html; charset=UTF-8, quoted-printable
       (RFC 2045 section 6.7), because some HTML bodies have lines far
       longer than the 998-octet limit of RFC 5322 section 2.1.1.
*/

signal on syntax name Failed
signal on notready name Failed

parse arg files
if files = '' then do
   say 'Usage: rexx groupsio2mbox.rex file.json [file.json ...]'
   exit 1
end

do file over files~makeArray(' ')
   converter = .Converter~new(file)
   say file':' converter~run 'messages written to' converter~output
end
exit 0

/* Failed -- report a SYNTAX or NOTREADY condition in one line instead
   of a traceback, and stop with return code 2 */
Failed:
   cond = condition('O')
   if cond = .nil then say 'Error:' condition('C') condition('D')
   else say 'Error' cond['CODE'] 'on line' cond['POSITION']':' cond['MESSAGE']
   exit 2

/* Converter -- turns one groups.io JSON file into an mbox file.
   input   the JSON file's path        output   the mbox file's path
   group   the group name ("netrexx")  rootOf   topic ID -> first message ID
   run     convert; return the count   message  one message as mbox text
   escapedBackslash, escapedQuote      escapes for a quoted display name */
::class Converter

/* The JSON file's path, as given on the command line */
::attribute input

/* The mbox file's path: input with its extension replaced by .mbox */
::attribute output

/* The group name from the JSON ("rexxla-arb"); it goes into each
   synthesized Message-ID, so IDs from different groups cannot collide */
::attribute group

/* Topic ID -> the message ID of the topic's first message in the file.
   Messages arrive oldest first, so the first one seen with a topic ID
   is the topic's start; later ones point to it in In-Reply-To and
   References (see the file header for why not the actual parent). */
::attribute rootOf

/* A display name goes in the From: header as a quoted string, where a
   backslash and a double quote must each be preceded by a backslash
   (RFC 5322 section 3.2.4). These are the escaped forms; the backslash
   is literal, as Rexx strings have no escape sequences. */
::constant escapedBackslash '\\'
::constant escapedQuote '\"'

/* init -- record the paths; nothing is read until run */
::method init
   use strict arg file
   self~input = file
   dot = file~lastPos('.')
   if dot > file~lastPos('\') & dot > file~lastPos('/') then
      self~output = file~left(dot - 1)'.mbox'
   else self~output = file'.mbox'
   self~rootOf = .directory~new

/* run -- read the JSON, write every message to the mbox file (replacing
   any earlier one), and return the number of messages written */
::method run
   in = .stream~new(self~input)
   in~open('READ')
   data = .json~new~fromJSON(in~charIn(1, in~chars))
   in~close
   self~group = data['group']
   out = .stream~new(self~output)
   out~open('WRITE REPLACE')
   count = 0
   do m over data['messages']
      out~charOut(self~message(m))
      count += 1
   end
   out~close
   return count

/* message -- one message as mbox text: the "From " separator line, the
   headers, a blank line, the quoted-printable body and a blank line,
   each line ending in LF (the mbox convention, RFC 4155) */
::method message
   use strict arg m
   LF = '0a'x
   id = m['id']
   topic = m['topic_id']
   msgId = '<'id'@'self~group'.groups.io.invalid>'
   if self~rootOf~hasIndex(topic) then root = self~rootOf[topic]
   else do
      self~rootOf[topic] = msgId
      root = ''
   end
   from = 'user-'m['user_id']'@groups.io.invalid'
   name = m['name']~changeStr('\', self~escapedBackslash)~changeStr('"', self~escapedQuote)
   text = .mutableBuffer~new
   text~append('From' from Stamp(m['created'], 'mbox'), LF)
   text~append('From: "'name'" <'from'>', LF)
   text~append('Date:' Stamp(m['created'], 'rfc5322'), LF)
   text~append('Subject:' OneLine(m['subject_with_tags']), LF)
   text~append('Message-ID:' msgId, LF)
   if root <> '' then do
      text~append('In-Reply-To:' root, LF)
      text~append('References:' root, LF)
   end
   text~append('X-Groupsio-Group:' self~group, LF)
   text~append('X-Groupsio-Message-Id:' id, LF)
   text~append('X-Groupsio-Msg-Num:' m['msg_num'], LF)
   text~append('X-Groupsio-Topic-Id:' topic, LF)
   text~append('X-Groupsio-User-Id:' m['user_id'], LF)
   if m['is_plain_text'] then text~append('X-Groupsio-Plain-Text: yes', LF)
   tags = m['hashtags']
   if tags~isA(.array) then do tag over tags
      text~append('X-Groupsio-Hashtag:' tag['name'], LF)
   end
   files = m['attachments']
   if files~isA(.array) then do a over files
      text~append('X-Groupsio-Attachment:' OneLine(a['filename']) '('a['media_type']')',
         a['download_url'], LF)
   end
   text~append('X-Reconstructed: From, Message-ID, In-Reply-To and References',
      'were made from groups.io metadata; the original headers are not available', LF)
   text~append('MIME-Version: 1.0', LF)
   text~append('Content-Type: text/html; charset=UTF-8', LF)
   text~append('Content-Transfer-Encoding: quoted-printable', LF)
   text~append(LF, QuotedPrintable(m['body']), LF, LF)
   return text~string

/* Stamp -- a groups.io time ("2026-09-05T17:28:38.092669998-07:00", an
   RFC 3339 timestamp) as an RFC 5322 Date ("Sat, 05 Sep 2026 17:28:38
   -0700") or as the asctime form of an mbox separator ("Sat Sep  5
   17:28:38 2026"). The time stays in the sender's zone, as written. */
::routine Stamp
   use strict arg created, style
   parse var created y '-' mo '-' d 'T' +1 hms +8
   zone = created~right(6)                      -- "-07:00", or ...":38Z"
   if zone~right(1) = 'Z' then zone = '+0000'
   else zone = zone~changeStr(':', '')
   sorted = y || mo || d
   day = date('W', sorted, 'S')~left(3)
   month = date('M', sorted, 'S')~left(3)
   if style = 'mbox' then return day month (d + 0)~right(2) hms y
   return day',' d month y hms zone

/* OneLine -- a header value with any CR or LF turned into blanks, so
   that a stray line break cannot end the header early */
::routine OneLine
   use strict arg header
   return header~translate('  ', '0d0a'x)

/* QuotedPrintable -- text encoded per RFC 2045 section 6.7: "=" and
   every byte outside printable ASCII (except tab) become =XX; blanks
   and tabs at a line's end become =20 / =09 (rule 3); lines are kept
   to 76 characters with "=" soft breaks (rule 5), never splitting an
   =XX. LF separates lines; a CR before an LF is dropped (it is part of
   the line break) and any other CR is encoded. A line starting "From "
   or ">From " has its first character encoded, for mbox (see header). */
::routine QuotedPrintable
   use strict arg text
   LF = '0a'x
   -- bytes that may stand for themselves: tab, then blank through "~"
   -- except "="
   safe = '09'x || xrange(' ', '<') || xrange('>', '~')
   out = .mutableBuffer~new
   lines = text~makeArray(LF)
   do i = 1 to lines~items
      line = lines[i]
      if line~right(1) = '0d'x then line = line~left(line~length - 1)
      codes = .array~new                     -- the line as output tokens
      at = 1
      if line~strip('L', '>')~abbrev('From ') then do
         codes~append('='line~left(1)~c2x)
         at = 2
      end
      do while at <= line~length
         bad = line~verify(safe, 'N', at)
         if bad = 0 then bad = line~length + 1
         if bad > at then codes~append(line~substr(at, bad - at))
         if bad <= line~length then codes~append('='line~substr(bad, 1)~c2x)
         at = bad + 1
      end
      -- rule 3: a blank or tab ending the line must be encoded
      if codes~items > 0 then do
         last = codes[codes~items]
         if last~right(1) == ' ' | last~right(1) == '09'x then do
            codes[codes~items] = last~left(last~length - 1)
            codes~append('='last~right(1)~c2x)
         end
      end
      -- rule 5: at most 75 characters plus a soft-break "=" per line
      width = 0
      do code over codes
         if code~left(1) = '=' then do       -- =XX: one indivisible unit
            if width + 3 > 75 then do
               out~append('=', LF)
               width = 0
            end
            out~append(code)
            width += 3
         end
         else do while code~length > 0
            if width = 75 then do
               out~append('=', LF)
               width = 0
            end
            take = min(75 - width, code~length)
            out~append(code~left(take))
            width += take
            code = code~substr(take + 1)
         end
      end
      if i < lines~items then out~append(LF)
   end
   return out~string

::requires 'json.cls'
