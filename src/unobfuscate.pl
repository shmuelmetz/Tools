#!/usr/bin/env perl
# Platform notes:
#   OS/2 / ArcaOS: add "extproc perl.exe -SW" as line 1
#   Windows:       file association handles dispatch; no first line needed
#   *ix / macOS:   this shebang line is correct; chmod +x the file
# The build script (build.rex) can prepend the correct line for each platform.
# Copyright 2006 by Shmuel (Seymour J.) Metz.
# <https://mason.gmu.edu/~smetz3>
# I hereby grant a license to anybody to distribute the
# unmodified code of this utility.
# Modified code may only be distributed if it is provided
# in source form and contains no dependencies on closed source
# software.

# T (taint) flag removed to avoid error message under OS/2 on the code
# foreach (`nslookup -type=any $NSkey 2>&1`)

# Insecure $ENV{PATH} while running with -T switch at
# unobfuscate line 926.

# Outstanding issues, in no particular order:
#
#   1. Track down problem with $RecPat
#   2. Add parsing for other Received formats
#   3. Analyze issues for scanning bare domain names and e-mail
#      addresses in body. It's easy to do, but I haven't figured out
#      whether it is desirable.
#   4. Add file globbing.
#   5. Add more Received consistency checks.
#   6. Extract fields from whois record
#   7. Create separate boilerplate file
#   8. Track down readline() on unopened filehandle DATA
#   9. Support IP V6 syntax for IP addresses.
#  10. Support more forms of redirect in doURI
#  11. Add MARF (RFC 5965) support using, e.g., Email::ARF::Report from
#      http://search.cpan.org/~rjbs/Email-ARF/lib/Email/ARF/Report.pm
#  12. Tighten up parsing of SWIP references
#  13. Handle SWIP loop
#  14. $prevHELO case independence
#  15. RFC 2606 domains
#  16. Look up MX
#  17. Parse invalid URI http://100-00.ru/durable.php

use 5.010;
#se Carp qw(cluck);
use charnames qw(:short);
use Data::Dumper;
use Devel::Peek;  # Debug only -- safe to comment out for production
use feature "switch";  # Deprecated in Perl >= 5.36; see "given/when" replacement
use File::Spec;
use Getopt::Long 2.3203 qw(:config auto_help auto_version);
#use HTML::Entities;
#$decoded = HTML::Entities::decode($a);
#HTML::Entities::decode($a);
use IO::File;
use Net::DNS;
use MIME::Parser;
#se MIME::Parser::Results;
use MIME::QuotedPrint;
use MIME::Tools;
use Pod::Usage;
use Regexp::Common qw /net URI/;
# $str =~ /$RE{net}{IPv4}/;
# $1 = entire match
# $2 = first quad
# $3 = second quad
# $4 = third quad
# $5 = fourth quad
# $str =~ /$RE{URI}{http}{-keep}{-scheme=qr(https?)}/;
# $1 = entire URI
# $2 = scheme
# $3 = host name or address
# $4 = port
# $5 = absolute path, including the query and leading slash
# $6 = absolute path, including the query, without the leading slash
# $7 = absolute path, without the query or leading slash
# $8 = query, without the question mark
#eval 'require Regexp::Common::URI::BADHTTP';
use Regexp::Common::URI::RFC2396 qw /$host $port $path_segments $query/;
#                           3986
use Socket;
use strict;
use warnings;
use URI::Escape;
# $str = uri_unescape($str);
# $str =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

#MIME:Tools->quiet(0);

my $abusenet;
my $cleanup;
my $debug;
my $help;
my $lookup;
my $man;

my $MARF;
my $MARFdesc = <<EOF;
The attached message is spam sent by your user.
EOF
my @MARF_fields;                        # Initialize inside of MAILFILE loop

my $ReceivedIx=0;
my %SWIP_DONE;

my $loopback = inet_aton '127.0.0.0';   # /8
my $mask8    = inet_aton '255.0.0.0';
my $mask12   = inet_aton '255.240.0.0';
my $mask16   = inet_aton '255.255.0.0';
my $RFC1918A = inet_aton '10.0.0.0';    # /8
my $RFC1918B = inet_aton '172.16.0.0';  # /12
my $RFC1918C = inet_aton '192.168.0.0'; # /16
my $temp = $ENV{UNOBFUSCATE_TEMP} || File::Spec->tmpdir();
# Override with --temp <path> or set UNOBFUSCATE_TEMP in your environment

# These are intended for use in parsing a URI as defined in RFC 3986 <http://www.ietf.org/rfc/rfc3986.txt>
# Extends Regexp::Common::URI to match hosts specified as integers.
# Blocks of regex definitions based on RFC 3986 begin with
# comments containing the relevant section or paragraph heading.

my $IPv4BinPat     = qr/ 0 [Bb] [01]{1,32} /x;
my $IPv4OctPat     = qr/ 0 [0-7]*+ /x;
my $IPv4DecPat     = qr/ [1-9] \d*+ /x;
my $IPv4HexPat     = qr/ 0 [Xx] [[:xdigit:]]{1,8} /x;
my $IPv4IntPat     = qr/ (?<INTIP>
                           $IPv4BinPat |
                           $IPv4OctPat |
                           $IPv4DecPat |
                           $IPv4HexPat
                         )
                         (?![[:alnum:].-])
                       /x;

#  3.2.2.  Host
my $decOctetPat    = qr/ 1 \d \d     |
                         2 [0-4] \d  |
                         25 [0-5]    |
                         [1-9] \d    |
                         \d
                       /x;
my $IPv4addressPat   = qr/ (?:$decOctetPat\.){3} $decOctetPat (?![[:alnum:].-]) /x;
my $IPv4OctetsPat    = qr/ ($decOctetPat) \. ($decOctetPat) \. ($decOctetPat) \. ($decOctetPat) /x;

# my $dottedQuadPat  = qr/ (?<O1>$OctetPat)\.(?<O2>$OctetPat)\.(?<O3>$OctetPat)\.(?<O4>$OctetPat) /x;
# my $DressedIPv4Pat = qr/\[$dottedQuadPat\]/x;

my $IPv6h16          = qr/[[:xdigit:]]{1,4}/;
my $IPv6ls32         = qr/ $IPv6h16 \: $IPv6h16 | $IPv4addressPat /x;
#                      Least significant 32 bits

my $IPv6AddrPat      = qr/ (?: (?: $IPv6h16 \: ){6}                                           $IPv6ls32 ) |
                           (?: \:\: (?: $IPv6h16 \: ){5}                                      $IPv6ls32 ) |
                           (?: (?: $IPv6h16 )?                      \:\: (?: $IPv6h16 \: ){4} $IPv6ls32 ) |
                           (?: (?: $IPv6h16 \: $IPv6h16 )?          \:\: (?: $IPv6h16 \: ){3} $IPv6ls32 ) |
                           (?: (?: (?: $IPv6h16 \: ){2} $IPv6h16 )? \:\: (?: $IPv6h16 \: ){2} $IPv6ls32 ) |
                           (?: (?: (?: $IPv6h16 \: ){3} $IPv6h16 )? \:\:     $IPv6h16 \:      $IPv6ls32 ) |
                           (?: (?: (?: $IPv6h16 \: ){5} $IPv6h16 )? \:\:                      $IPv6ls32 ) |
                           (?: (?: (?: $IPv6h16 \: ){6} $IPv6h16 )? \:\:                                    )
                         /x;
my $DressedIPv6Pat   =  qr/\[$IPv6AddrPat\]/x;

#  3.1.  Scheme
my $SchemePat      = qr/ (?<SCHEME> ftp | https? | mailto) /ix;
#                    Dont't need the others

#  2.3.  Unreserved Characters
my $unreserved     = qr/[-_.~[:alnum:]]/x;

#  2.2.  Reserved Characters
my $subDelims      = qr/[!\$&'()*+,;=]/x;

#  2.1.  Percent-Encoding
my $HexEncPat      = qr/\% [[:xdigit:]]{2}/x;

#  3.2.1.  User Information
my $userinfoPat    = qr/(?<USERINFO> (?:$unreserved | $HexEncPat | $subDelims | [:])*)/x;

#  3.2.2.  Host

my $regNamePat     = qr/(?:$unreserved | $HexEncPat | $subDelims)*/x;
#y $hostPat        = qr/ (?<HOST> $DressedIPv6Pat | $IPv4addressPat | $IPv4IntPat | $regNamePat) /x;
#                    The host component is more restrictive for the URI schemes that I use

#                    RFC 5321 4.1.2.  Command Argument Syntax
my $domainPat      = qr/[[:alnum:]]++
                        [[:alnum:]-]*+
                        (?:\. [[:alnum:]]++[[:alnum:]-]*+)*+
                       /x;

my $hostPat           = qr/
                            (?<HOST>
                              $DressedIPv6Pat |
                              $IPv4addressPat |
                              $IPv4IntPat     |
                              $domainPat
                            )
                       /x;

#  3.2.3.  Port
my $portPat        = qr/ (?<PORT> \d*+) /x;

#  3.3.  Path
my $pchar          = qr/$unreserved | $HexEncPat | $subDelims | [:@]/x;

my $segment        = qr/ $pchar* /x;
my $seg_nz         = qr/ $pchar+ /x;
my $seg_nz_nc      = qr/ (?: $unreserved | $HexEncPat | $subDelims | \@)+ /x;

my $pathAbEmpty    = qr{ (?<PATH> (?: / $segment)*       ) }x;
my $pathAbsolute   = qr{ (?<PATH> / (?:$seg_nz (?: / $segment)*)?) }x;
my $pathNoScheme   = qr{ (?<PATH> $seg_nz_nc (?: / $segment)*) }x;
my $pathRootless   = qr{ (?<PATH> $seg_nz (?: / $segment)*) }x;
my $pathEmpty      = qr{ (?<PATH>                        ) }x;

my $pathPat        = qr/ $pathAbEmpty  |
                         $pathAbsolute |
                         $pathNoScheme |
                         $pathRootless |
                         $pathEmpty
                       /x;

#  3.2.  Authority
my $authority      = qr/ (?:$userinfoPat\@)? $hostPat (?:\:$portPat)? /x;

#  3.4.  Query
my $queryPat       = qr/ (?<QUERY> (?:$pchar | [\/?])*) /x;

#  3.5.  Fragment
my $fragmentPat    = qr/ (?<FRAGMENT> (?:$pchar | [\/ ?])*) /x;

#  3.  Syntax Components
my $hierPart       = qr{ // $authority  $pathAbEmpty |
                         $pathAbsolute               |
                         $pathRootless               |
                         $pathEmpty
                       }x;

my $URIpat        = qr/ \b (?<URI>$SchemePat [:] $hierPart (?:[?] $queryPat)? (?:[#] $fragmentPat)?) /x;



$main::VERSION = '0.940004';
GetOptions ('abusenet!'=> \$abusenet,
            'cleanup!'=> \$cleanup,
            'debug!' => \$debug,
            'help!' => \$help,
            'lookup!' => \$lookup,
            'man' => \$man,
            'MARF!' => \$MARF,
            'received=i' => \$ReceivedIx,
            'temp=s' => \$temp)
                                    or pod2usage( { '-exitval' => 2,
                                                    '-verbose' => 0 } );
if ($man) {
  pod2usage( { '-exitval' => 1,
               '-verbose' => 2 } );
} elsif ($help) {
  pod2usage( { '-exitval' => 1,
               '-verbose' => 1 } );
};

my $boilerplate = <<EOF;
Use due diligence in deciding to which addresses in this report you
should send a complaint. In particular, not every URL that occurs
in a spam message is a drop box.

EOF

my $IsRecIx = <<EOF;
You requested --received=$ReceivedIx; this report omits the first $ReceivedIx
Received header fields.  If you are complaining about spam posted
to a mailing list, include the Received header fields for the
list's internal routing in the --received value.

EOF

my $NoRecIx = <<EOF;
You did not specify the --received option; this report includes all
Received header fields and you should ignore those that are part of
your provider's internale routing.  If you are complaining about
spam posted to a mailing list, uou should also ignore the Received
header fields for the list's internal routing.

EOF

#if ($debug) {
# msg("\nDump(\$mask8)\n");
# Dump ($mask8);
# msg("\nDump(\$mask12)\n");
# Dump ($mask12);
# msg("\nDump(\$mask16)\n");
# Dump ($mask16);
# msg("\nDump(\$RFC1918A)\n");
# Dump ($RFC1918A);
# msg("\nDump(\$RFC1918B)\n");
# Dump ($RFC1918B);
# msg("\nDump(\$RFC1918C)\n");
# Dump ($RFC1918C);
#}

MIME::Tools->debugging(1) if $debug;
my $parser = new MIME::Parser;
$parser->output_under($temp);
$parser->extract_uuencode(1);
my $filer = $parser->filer;

#                       RFC 5321  4.1.2.  Command Argument Syntax
my $addressLiteralPat = qr/\[
                           (?:$IPv4addressPat |
                              $IPv6AddrPat
                           )
                           \]
                          /x;

#                       RFC 5322 3.2.3.  Atom
my $atextPat          = qr"(?:[\w!#\$%&'*+/=?^`{|}~-]++)";

#                      RFC 5322 3.2.2.  Folding White Space and Comments
#y $FWS               = qr/ (?:[ \t]*\15?\12)?+ [ \t]++ /x;
my $FWS               = qr/ (?:[ \t]*+\R)?+ [ \t]++ /x;

#                      RFC 5322 3.2.3.  Atom
my $atomPat           = qr/$atextPat++/x;

#                      RFC 5322 3.2.2.  Folding White Space and Comments
my $ctext             = '[\x21-\x27\x2A-\x5B\x5D-\x7E]';

#                      RFC 5322 3.2.1.  Quoted characters
my $quotedPairPat     = qr/ \\ [\x20-\x7E] /x;

#                      RFC 5322 3.2.2.  Folding White Space and Comments
my $commentPat        =qr/
                           \(
                           (?:$FWS?+
                              (?:$ctext | $quotedPairPat    | (?R))
                           )*
                           $FWS?+
                           \)
                         /x;

#                      RFC 5322 3.2.2.  Folding White Space and Comments
my $CFWS              = qr/
                           (?: (?:$FWS+ $commentPat)++ $FWS?+) |
                           $FWS
                          /x;

#                       RFC 5322 3.3.  Date and Time Specification
#                       RFC 5322 4.3.  Obsolete Date and Time
my $dayPat            = qr/$CFWS?+ (?<DAY>\d{1,2}) $CFWS?+/x;

#                       RFC 5322 3.3.  Date and Time Specification
#                       per RFC 5322 case matters
my $day_of_weekPat    = qr/
                           $CFWS
                           (?<DAY_OF_WEEK>
                              Mon |
                              Tue |
                              Wed |
                              Thu |
                              Fri |
                              Sat |
                              Sun
                           )
                           $CFWS?+
                          /x;

#                      RFC 5322 3.2.3.  Atom
my $dotStringPat      = qr/$atextPat++ (?:\. $atextPat)*+/x;
my $dtextPat          = '[\x21-\x50\x54-\x7E]';

#                       RFC 5322 3.3.  Date and Time Specification
my $hourPat           = qr/(?<HOUR>
                             (\d\d)
                             (?(?{$^N > 24})
                               (*FAIL)
                             )
                           )
                          /x;

my $idLeftPat         = qr/$dotStringPat/;
my $LinkPat           = qr/TCP | $atomPat/xi;
my $noFoldLiteralPat  = qr/\[ $dtextPat* \]/x;
my $idRightPat        = qr/$dotStringPat | $noFoldLiteralPat/x;
my $msgIdPat          = qr/\s*+ \< $idLeftPat \@ $idRightPat \> \s*+/x;

#                       RFC 5322 3.3.  Date and Time Specification
my $minutePat         = qr/(?<MINUTE>
                             (\d\d)
                             (?(?{$^N > 59})
                               (*FAIL)
                             )
                           )
                          /x;

#                       RFC 5322 3.3.  Date and Time Specification
#                       per RFC 5322 case matters
my $monthPat          = qr/
                           (?<MONTH>
                             Jan |
                             Feb |
                             Mar |
                             Apr |
                             May |
                             Jun |
                             Jul |
                             Aug |
                             Sep |
                             Oct |
                             Nov |
                             Dec
                           )
                          /x;

#                       RFC 5322 4.3.  Obsolete Date and Time
my $obs_zonePat       = qr/
                           CDT             |
                           CST             |
                           EDT             |
                           EST             |
                           GMT             |
                           MDT             |
                           MST             |
                           PDT             |
                           PST             |
                           UT              |
                           [A-IK-Za-ik-z]
                          /x;

my $qtextPat          = '[\x20-\x21\x23-\x5B\x5d-\x7E]';
my $QcontentPat       = qr/$qtextPat | $quotedPairPat/x;
my $QuotedStringPat   = qr/"$QcontentPat*"/;

my $rDNSstat          =qr/
                           \s*+
                           (?:\s*+ \( may \s be \s forged \) )     |
                           (?: \s*+ \( misconfigured \s sender \) ) |
                           (?: \s*+ RDNS \s failed)
                          /x;

#                      Non-5321 prefix to domain in TCP-INFO
my $RecLocalPat       = '(?:(?:IDENT:)?[\w+-]+[\w\.+-]*@)?+';

#                       RFC 5322 3.3.  Date and Time Specification
my $secondPat         = qr/(?<SECOND>
                             (\d\d)
                             (?(?{$^N > 59})
                               (*FAIL)
                             )
                           )
                          /x;

#                       RFC 5321 4.4.  Trace Information
#                       Malformed Received headers may have 'RDNS failed'
#                       after the IP address, a dressed IP address abutted
#                       to the rDNS or a dotted quad without framing []
my $TCPinfoPat        =qr/
                          (?>
                            (?<IP>$addressLiteralPat) (?:\s*+ RDNS \s failed)?+        |
                            (?<IP>$IPv4addressPat)                                     |
                            (?:$RecLocalPat
                               (?<RDNS>$domainPat)
                               $FWS?+
                               (?<IP>$addressLiteralPat)
                               $rDNSstat*+
                            )
                          )
                         /x;

#                       RFC 5322 3.3.  Date and Time Specification
my $time_of_day       = qr/$hourPat : $minutePat (?: : $secondPat)?/x;

my $vcharPat          = '[\21-\7E]';

#                       RFC 5322 3.3.  Date and Time Specification
#                       RFC 5322 4.3.  Obsolete Date and Time
my $yearPat           = qr/$FWS (?<YEAR>\d{2,4}) $FWS/x;

#                       RFC 5322 3.3.  Date and Time Specification
#                       RFC 5322 semantic constraint not applied in order to match malformed zones.
my $zonePat           = qr/$FWS
                           (?<ZONE>
                             (?:
                                (?:
                                   [+-]
                                   \d\d\d\d
                                )                    |
                                $obs_zonePat
                             )
                           )
                          /x;

#                       RFC 5322 shows spaces in day and year, not here
my $datePat           = qr/$dayPat $monthPat $yearPat/x;

#                       Received: FROM non-5321 tokens seen in the wild
my $Non5321DomainPat  = qr/
                           \.              |
                           $IPv4addressPat |
                           \d++
                          /x;

#                       Malformed Received headers may have a leading hyphen in a
#                       domain name, a period as a domain name or an address
#                       literal without TCPINFO. They may also have an IPv4
#                       address expressed as a hexadecimal, decimal or octal constant.
my $ExtendedDomainPat = qr/
                           (?:(?<HELO>-?+$domainPat) \s? (?<IP>$addressLiteralPat)) |
                           (?:(?<HELO>-?+$domainPat) (?:$FWS \( $TCPinfoPat \))?+) |
                           (?<IP>$addressLiteralPat) (?:$FWS \( $TCPinfoPat \))?+  |
                           $Non5321DomainPat         (?:$FWS \( $TCPinfoPat \))?+
                          /x;

my $localPartPat      = qr/$dotStringPat | $QuotedStringPat/x;
my $MailboxPat        = qr/
                           (?<MAILBOX>
                            (?<LOCAL_PART>$localPartPat)
                            \@
                            (?<DOMAIN>$domainPat | $addressLiteralPat)
                           )
                          /x;

my $RFC2606pat        = qr/
                           \.
                           (
                            example       |
                            example\.com  |
                            example\.net  |
                            example\.org  |
                            invalid       |
                            localhost     |
                            test
                           )
                           $
                          /ix;
my $TLDpat            = qr/^[[:alnum:]-]+$/ix;
my $notTLDpat         = qr/^[[:alnum:]-]+(?:\.[[:alnum:]-]+)+$/ix;

#                       RFC 5321 4.4.  Trace Information
my $protocolPat       = qr/SMTP | ESMTP | $atomPat/xi;

#                       RFC 5321 4.1.2. Command Argument Syntax
#                       I don't expect to see source routing in the wild
my $RecPathPat        = qr/
                           \<
                           (?:\@ $domainPat (?:, \@ $domainPat)* :)?
                           $MailboxPat
                           \>
                          /x;

#                       Can't use $RE{net}{domain} due to malformed domain names
my $RecHELOpat        = "(?<HELO>(?:-?$domainPat)|" .
                        "\\.|"                      .
                        "$addressLiteralPat      |" .
                        "$IPv4addressPat|"          .
                        "\\d++)";

#                       Road Runner Received: FROM
my $RRfromPat         = qr/
                           (?<HELO>$IPv4addressPat)
                           \s+
                           \(
                             Forwarded-For:
                             \s
                             $addressLiteralPat
                           \)
                          /x;

#                       QMAIL Received: FROM
my $QMfromPat         = qr/(?<IP>$IPv4addressPat)
                           \s+
                           \(
                             \[
                               (?<RDNS>$domainPat)
                             \]
                             :
                             \d++
                             \s++
                             "
                               \w++
                               \s*+
                             \[
                               (?<HELO>$domainPat)
                             \]
                             "
                             [^)]*+
                           \)';
                          /x;

my $RecSrcPat         = qr/$RecLocalPat
                           (?<RDNS>$domainPat)?
                           \s*+
                           $addressLiteralPat
                           \s*+
                           (?:\(may\sbe\sforged\))?
                           \s*+
                           (?:\(misconfigured\ssender\))?
                           \s*+
                           (?:\s*+RDNS\sfailed)?
                          /x;

#                       RFC 5321 4.4.  Trace Information
#                       The RFC 5321 syntax for From-domain does not allow an address literal without
#                       TCP-info in parentheses, but Yahoo creates a Stamp in that format.
#                       Some software puts significant information in comments beyond the
#                       TCPINFO of the Extended-Domain.
my $RecFromPat        = qr/^
                           FROM
                           $FWS
                           (?<FROM>
                             (?:
                                (
                                  \[
                                    (?<IP>$IPv4addressPat)
                                  \]
                                )
                                \s*+
                                \(
                                  HELO=$RecHELOpat
                                \)
                             )                                |
                             (?:(?<RDNS>$domainPat)
                                \s++
                                \(
                                  \[
                                    (?<IP>$IPv4addressPat)
                                  \]
                                  (?:
                                    :
                                    (?<PORT>\d++)
                                  )?+
                                  \s++
                                  HELO=$RecHELOpat
                                \)
                             )                                |
                             (?:(?<RDNS>$domainPat)
                                \s++
                                \(
                                  HELO
                                  \s
                                  $RecHELOpat
                                \)
                                \s++
                                \(
                                  \[
                                    (?<IP>$IPv4addressPat)
                                  \]
                                \)
                             )                                  |
                             $ExtendedDomainPat                 |
                             $QMfromPat                         |
                             $RRfromPat
                           )
                          /xi;

#                       RFC 5321 4.4.  Trace Information
#                       per RFC 5321 it's CFWS "BY" FWS Extended-Domain
#                       in the wild it's CFWS "BY" FWS Domain FWS '(' MTA ')'
my $RecByPat          = qr!$CFWS
                           BY
                           $FWS
                           (?<BY1>
                             (?:$domainPat                   |
                                $addressLiteralPat
                             )
                           )
                           (?:
                              $FWS
                              \(
                                (?<BY2>[\s\w\./[\]-]+)
                              \)
                           )?+
                           (?:
                              $FWS
                              \(
                                (?<BY3>[\w-]++ , \s*+ port \s \d++)
                              \)
                           )?+
                          !xi;

#                       RFC 5321 4.4.  Trace Information
my $RecForPat         = qr/$CFWS FOR $FWS (?: $RecPathPat | $MailboxPat)/xi;

#                       Malformed Received header fields may have atom in <> or msg-id without <>
my $RecIdPat          = qr/
                           $CFWS
                           ID
                           $FWS
                           (?<ID>
                             $atomPat                  |
                             $msgIdPat                 |
                             $idLeftPat \@ $idRightPat |
                             \< $atomPat \>
                           )
                          /xi;

my $RecViaPat         = qr/$CFWS VIA $FWS (?<LINK>$LinkPat)/xi;

#                       m$ lookout violates RFC 5321 syntax
my $RecWithMS         = qr/Microsoft \s+ (?:ESMTP|SMTP) (?:\s+ Server | SVC\(\d+(?:\.\d+)*\))/xi;
my $RecWithPat        = qr/$CFWS
                           WITH $FWS
                           (?:
                             (?:ESMTP|SMTP) \w*+                     |
                             $RecWithMS                              |
                             NNFMP                                   # Yahoo
                           )
                           (?:
                             $FWS
                             \(
                               (?:
                                 Exim |
                                 SMTP
                               )
                               [ \d\w\.-]*+
                             \)
                           )?+
                          /xi;

my $RecOptInfo        = qr/
                           (?<VIA>$RecViaPat)?+
                           (?<WITH>$RecWithPat)?+
                           (?:$RecIdPat)?
                           (?<FOR>$RecForPat)?
                          /xi;

my $timePat           = qr/$time_of_day $zonePat/x;

#                       RFC 5322 shows spaces in day and year, not here
my $date_timePat      = qr/
                           (?: $day_of_weekPat [,])?+
                           $datePat
#                          $timePat
#                          (?:$CFWS)?+
                          /x;

my $RecPat            = qr/^
                          $RecFromPat
                          $RecByPat
                          $RecOptInfo
                          $CFWS?
                          \;
                          (?<DATETIME>$date_timePat)
                       /x;

my $relayedDom        = q/marist\.edu/;
my $spoofedDom        = q/akamai\.com|akami\.net|amazon\.com|ebay\.co\.uk|ebay\.com|ebayobjects\.com|ebaystatic\.com|marist\.edu|paypal\.com|wellsfargo\.com/;
#                       Need to redo to handle
#                       %2F /  Do we need?
#                       %30-%39 09
#                       %41-%5A AZ
#                       %61-%7A az

#                       Similar to mailto URI but allows leading words and white space.
my $localAtom         = "(?:[\\w!#\$%&'*+/=?^_`{|}~-]+)";
my $mailbox           = qr/$localAtom(?:\.$localAtom)*\@(?<HOST>$domainPat)/;
my $mailToTag         = '(?:email|e-mail|mailto|contact\s++to)';
#y $mailtoPat         = qr/($mailToTag:\s*+(?:\w+\s+)*?($mailbox))/i;
my $mailtoPat         = qr/
                            (?<PSEUDOURI>
                              $mailToTag:
                              \s*+
                              (?: \w+ \s+)*?
                              (?<MAILBOX>$mailbox | <$mailbox>)
                            )
                          /xi;


my $ContactTagPat = qr/
                       (
                         (?: (?:[\w-]+\s*+)+ -?mailbox:)      |
                         (?: (?:[\w-]+\s*+)*e -?mail:)        |
                         (?: (?:\w\.\s+) \[e-?mail\])            |
                         (?: trouble: \s++ (?:abuse|spam) :)
                       )
                      /xi;

my $SWIPblockPat = qr/
                      \s*
                      \R?
                      \s*
                      (?<IPblock>$IPv4addressPat\s*-\s*$IPv4addressPat)
                     /x;
my $SWIPidPat    = qr/\s+(?<id>[\w]+(?:-[\w-]+)?)/;
my $SWIPnetPat   = qr/\s*\((?<net>[\w-]+)\)/;
my $SWIPfragPat  = qr'[\@\w&,\./!-]+';
my $SWIPnamePat  = qr/(?<name>$SWIPfragPat(?:\s*$SWIPfragPat)+)/;
my $SWIPdescPat  = qr/\R\s*(?<desc>$SWIPnamePat$SWIPidPat)/;
my $SWIPpat      = qr/$SWIPdescPat$SWIPnetPat$SWIPblockPat/;

#  Moved out of mailfile: while to avoid scope issues with subroutines in loops
my %host_info;
my $prevBogus;
my $prevHELO;
my $prevIP;
my $prevSrc;

my $resolver;
if ($^O eq 'os2') {
   $resolver = Net::DNS::Resolver->new(debug => $debug?1:0, config_file => $ENV{'ETC'}.'/resolv');
} else {
   $resolver = Net::DNS::Resolver->new(debug => $debug?1:0);
}
$resolver->print;

mailfile: while (my $mailfile=shift) {
  print STDOUT "\nunobfuscate.cmd processing file $mailfile\n";
  my $entity = $parser->parse_open("$mailfile")
    or die "$mailfile parse failed\n";
  msg("\nDumper(\$entity)\n");
  msg(Dumper($entity));
  my $results = $parser->results;
  msg("\nDumper(\$results)\n");
  msg(Dumper($results));
  my @msgs = $results->msgs;
  my @had_errors = $results->errors;
  my @had_warnings = $results->warnings;
  msg("warnings:\n",@had_warnings,"\n") if @had_warnings;

  ### Take a look at the top-level entity (and any parts it has):
  $entity->dump_skeleton if ($debug);

  my $head = $entity->head;
  msg("\n\$filer->output_dir(\$head)=",$filer->output_dir($head),"\n");
  my $encoding = $head->mime_encoding;

  undef %host_info;
  undef $prevBogus;
  undef $prevHELO;
  undef $prevIP;
  undef $prevSrc;

  @MARF_fields = (
                  'Feedback-Type' => 'abuse'
                 );

  # Process Received header fields
  my @Received = $head->get_all('Received');
  if ($debug) {
    print STDERR "\n\$prevHELO=", $prevHELO//'undef', "\n";
    msg("\n\@Received has ",scalar(@Received)," lines\n");
    foreach (@Received) {
      my $thisStamp = $_;
#     $thisStamp =~ s/\x0A/\n\t  <LF>\n/;
#     $thisStamp =~ s/\x0D/\n\t  <CR>\n/;
      msg("\t->$thisStamp\n");
#     if (/^$RecFromPat $RecByPat/xi) {
#     if (/($RecByPat $RecOptInfo?)/xi) {
#     use re 'debug';
      if (/($RecPat)/xi) {
#     if (/($RecFromPat  $RecByPat $RecOptInfo)/xi) {
          print STDERR "\nReceived matched '$1':\n";
          foreach my $key (sort keys %-) {
            print STDERR "\$-{$key}=",grep defined, @{$-{$key}},"\n";
#           print STDERR "\$-{$key}=",Dumper($-{$key}),"\n";
          }
          print STDERR "\n";
          print STDERR "\nCount \%+=",scalar %+, "\n";
          print STDERR "\nkeys \%+=", keys %+, "\n";
#         print STDERR "\nDumper(\%+)=", Dumper(%+), "\n";
          print STDERR "\n";
          foreach my $key (sort keys %+) {
            print STDERR "\$+{$key}=$+{$key}\n";
          }
          print STDERR "\n";
      }
    }
  }
# msg("\n\$RecSrcPat=$RecSrcPat\n");
  foreach (@Received[$ReceivedIx..$#Received]) {
    msg("\nmatching against $_\n");
    my $From;
    my $HELO;
    my $rDNS;
    my $IP;
    my $by1;
    my $by2;
    if (/($RecPat)/xi) {
#   if (/^
#        from \s+ ($RecHELOpat \s*+ \( $RecSrcPat \))
#        $RecByPat? $RecOptInfo
#       /xi                                                   ||
#       /^
#        from \s+ ($RecHELOpat \s*+ \((?<IP>$RE{net}{IPv4}) (?:\s*+RDNS failed)?\))
#        $RecByPat? $RecOptInfo?
#       /xi                                                   ||
#       The RFC 5321 syntax for From-domain does not allow an address literal without
#        TCP-info in parentheses, but Yahoo creates a Stamp in that format.
#       /^
#        from \s+ ((\[(?<IP>$RE{net}{IPv4})\]) (?:\s*+ \(HELO=$RecHELOpat\))?)
#        $RecByPat? $RecOptInfo?
#       /xi                                                   ||
#       /^
#        from \s+ ((?<RDNS>$domainPat) \s+ \(\[(?<IP>$RE{net}{IPv4})\] \s+ HELO=$RecHELOpat\))
#        $RecByPat? $RecOptInfo?
#       /xi                                                   ||
#       /^
#        from \s+ ((?<RDNS>$domainPat) \s+ \(HELO\s$RecHELOpat\) \s+ \(\[(?<IP>$RE{net}{IPv4})\]\))
#        $RecByPat? $RecOptInfo?
#       /xi                                                   ||
#       /^
#        from \s+ ($QMfromPat)
#        $RecByPat? $RecOptInfo?
#       /xi                                                   ||
#       /^
#        from \s+ ($RRfromPat)
#        $RecByPat? $RecOptInfo?
#       /xi
#      )
#   {
      if ($debug) {
        print STDERR "\nReceived matched:\n";
        foreach my $key (sort keys %-) {
          print STDERR "\$-{$key}=",grep defined, @{$-{$key}},"\n";
        }
        print STDERR "\n";
        print STDERR "\nCount \%+=",scalar %+, "\n";
        print STDERR "\nkeys \%+=", join(', ', keys %+), "\n";
        foreach (sort keys %+) {
          print STDERR "\$+{$_}=$+{$_}\n";
        }
        print STDERR "\n";
      }
      doReceived($+{FROM},
                 $+{HELO} // $+{IP},
                 $+{RDNS} // '',
                 $+{IP},
                 $+{BY1},
                 $+{BY2}  // '',
                 $+{DATETIME} // '',
                 $+{MAILBOX} // '',   # from For clause
                 $+{ID}
                )                     || last;
    } else {
#     if (/($RecFromPat $RecByPat (?<VIA>$RecViaPat)?+ (?<WITH>$RecWithPat)?+ (?:$RecIdPat)?  (?<FOR>$RecForPat)?  $CFWS? \;)/x) {
#        print STDERR "\nReceived By matched '$1':\n";
#        print STDERR "\nTail='${'}'\n";
#        foreach my $key (sort keys %-) {
#          print STDERR "\$-{$key}=",grep defined, @{$-{$key}},"\n";
#        }
#     }
      last;
    }
  }

  # Process Reply-To header field
  my @ReplyTo = $head->get_all('Reply-To');
  foreach (@ReplyTo) {
    msg("Found reply-to: $_\n");
  }
  use Mail::Address;
  my @addrs = Mail::Address->parse("@ReplyTo");
  foreach (@addrs) {
    msg("Parsed reply-to $_\n");
    my $phrase  = $_->phrase;
    my $address = $_->address;
    my $comment = $_->comment;
    my $name    = $_->name // '';
    my $host    = $_->host;
    my $format  = $_->format;
    msg("\t\$phrase  = $phrase\n");
    msg("\t\$address = $address\n");
    msg("\t\$comment = $comment\n");
    msg("\t\$name    = $name\n");
    msg("\t\$host    = $host\n");
    msg("\t\$format  = $format\n");
    doURI("Reply-To: $format", $host, undef(), '', '') if $host;
  }

  # Process Return-Path header field to obtain relevant reverse path
  if (my $ReturnPath = $head->get('Return-Path')) {
    my ($ReversePath) = Mail::Address->parse($ReturnPath);
    msg("Parsed Return-Path $ReturnPath\n");
    my $phrase  = $ReversePath->phrase;
    my $address = $ReversePath->address;
    my $comment = $ReversePath->comment;
    my $name    = $ReversePath->name // '';
    my $host    = $ReversePath->host;
    my $format  = $ReversePath->format;
    msg("\t\$phrase  = $phrase\n");
    msg("\t\$address = $address\n");
    msg("\t\$comment = $comment\n");
    msg("\t\$name    = $name\n");
    msg("\t\$host    = $host\n");
    msg("\t\$format  = $format\n");
    doURI("Return-Path: $format", $host, undef(), '', '')  if $host;
    push @MARF_fields, ('Original-Mail-From'   => $format) if $format && $format ne '<>';
  } else {
    msg("\n\$ReturnPath =", $ReturnPath // 'undef', "\n");
  }

  # Process header fields for news origin
  # RFC 2980 NNTP-Posting-Host is obsolete per RFC 5536 but is still in use
  my @origin = $head->get_all('X-Originating-IP'),
               $head->get_all('X-Originating-IP-Addr');
  foreach (@origin) {
    chomp $_;
    msg("Found X-Originating-IP: |$_|\n");
    if (/^([\d\.]+)(?:\s*+\([\s\w\.-]*+\))?+$/ ||
        /^\[([\d\.]+)\](\s*+\([\s\w\.]*+\))?$/) {
      my ($IP, $skipIP) = doIP($1);
      msg("After doIP($1), \$IP=$IP, \$skipIP=$skipIP\n");
      $host_info{$IP}{NetNews}="X-Originating-IP specified as $_";
      push @{$host_info{$IP}{msg}},
           ": the spam was posted by $skipIP $_ in your IP space.\n";
    }
  }

  my @newsHost = $head->get_all('NNTP-Posting-Host'),
                 $head->get_all('X-Original-NNTP-Posting-Host');
# if ($debug) {
#   print STDERR "\nIntermediate \@newsHost has ",scalar(@newsHost)," lines\n";
#   foreach (@newsHost) {
#     msg("\t->|$_|\n");
#     msg("\t->hex ",unpack('H*',$_),"\n");
#   }
# }
  chomp @newsHost;
  push @newsHost, map {if (/posting-host=($RE{net}{IPv4}|$domainPat)/) {$1;}}
                  $head->get_all('Injection-Info');
  msg("\n\@newsHost has ",scalar(@newsHost)," lines\n");
  foreach (@newsHost) {
    msg("\t->|$_|\n");
  }
  foreach (sortunique(@newsHost)) {
    chomp $_;
    next if /^$/;
    s/\([^)]*\)//g;
    my $URI = "NNTP-Posting-Host: $_";
    if (/^$RE{net}{IPv4}{-keep}$/) {
      next if localIP(inet_aton $_);
      my $IP = "[$_]";
      $host_info{$IP}{NetNews}='NNTP-Posting-Host';
      push @{$host_info{$IP}{msg}},
           ": the spam was posted from $IP in your IP space.\n";
      msg("doURI('$URI', '$IP', '', '', '')\n");
      doURI($URI, $IP, undef(), '', '');
    } else {
      my $host = uc $_;
      $host_info{$host}{NetNews}='NNTP-Posting-Host';
      push @{$host_info{$host}{msg}},
           ": the spam was posted from $host.\n";
      msg("doURI('$URI', '$host', '', '', '')\n");
      doURI($URI, $_, undef(), '', '');
    }
  }

  my $bodyh = $entity->bodyhandle;
# msg("\nDumper(\$bodyh)\n");
# msg(Dumper($bodyh));
  my $hostinfo;
  my $fhLookup;
  my $path = $filer->output_dir($head);
  if ($lookup && $path) {
     msg("\nMessage parts stored in $path\n");
     $hostinfo = File::Spec->catfile($path,'lookupinfo');
     msg('Lookup information will be stored in ', $hostinfo, "\n");
     open($fhLookup,'>>',$hostinfo) or die "\nCan't open $hostinfo\n";
  }
  else {
     $fhLookup = \*STDOUT;
  }

  my $type = $entity->mime_type;
  my $eff_type = $entity->effective_type;

  my $preamble   = $entity->preamble;       ### ref to array of lines
  my @parts      = $entity->parts;
  my $num_parts  = $entity->parts;
  my $epilogue   = $entity->epilogue;       ### ref to array of lines

  msg("\n\$encoding: $encoding\n");
  msg("\n\$type: $type\n");
  msg("\n\$encoding: $encoding\n");

  if (defined $preamble) {
#   msg("\nDumper(\$preamble)\n");
#   msg(Dumper($preamble));
    msg("\$preamble=$preamble\n");
    msg("\$preamble has ",scalar(@$preamble)," lines\n");
    foreach (@$preamble) {
      msg("\t->$_\n");
    }
  }

  msg("\$num_parts: ",$num_parts,"\n");

  if (defined $epilogue) {
    msg("\$epilogue has ",scalar(@$epilogue)," lines\n");
    foreach (@$epilogue) {
      msg("\t->$_\n");
    }
  }
  if ($bodyh) {
      msg("\ndopart(\$entity)\n");
      dopart($entity);
  }
  part: foreach my $part (@parts) {
#   msg("\nDumper(\$part)\n");
#   msg(Dumper($part));
    msg("\ndopart(\$part)\n");
    dopart($part);
  }
# msg("\nDumper(\$host_info)\n");
# msg(Dumper(%host_info));
  print $fhLookup "\nUnobfuscate $main::VERSION analysis of $mailfile", $hostinfo?" on $hostinfo\n":"\n",
                  $boilerplate;
  if ($ReceivedIx) {
    print $fhLookup $IsRecIx;
  } else {
    print $fhLookup $NoRecIx;
  };
  foreach my $host (sort keys %host_info) {
    if (my $skip=$host_info{$host}{skip}) {
      print $fhLookup "\ne-mail and URL list for $skip:\n";
#   my $skipIP=$host_info{$host}{skipIP};
#   if ($skipIP) {
#     print $fhLookup "\ne-mail and URL list for internal $skipIP IP address $host:\n";
    } else {
      print $fhLookup "\ne-mail and URL list for host $host:\n";
    };
    if (my $newsField=$host_info{$host}{NetNews}) {
      print $fhLookup "\tNetNews:\t$newsField\n";
    };
    foreach my $SMTP (sort keys %{$host_info{$host}{SMTP}}) {
      print $fhLookup "\tSMTP:\t$SMTP\n";
    };
    foreach my $URL (sort keys %{$host_info{$host}{URL}}) {
      print $fhLookup "\tURL:\t$URL\n";
    };
  };
# msg("\nDumper(\%host_info) before lookup\n");
# msg(Dumper(%host_info));
  if ($lookup) {
    foreach my $host (sort keys %host_info) {
      my $skipIP=$host_info{$host}{skipIP};
      if ($skipIP) {
        # may need additional code here;
        # otherwise change to if clause on next.
        next;
      } elsif ($host_info{$host}{NoLookup}) {
        # may need additional code here;
        # otherwise change to if clause on next.
        next;
      }
      unless ($host_info{$host}{skipIP}) {
        my $isIP = $host =~ /\[([\d\.]+)\]/o;
        $host_info{$host}{isIP}=$isIP;
        my $name;
        my $aliases;
        my $addrtype;
        my $length;
        my @addrs;
        my @IP;
        if ($isIP) {
          my $addr = inet_aton $1;
          msg("\n\$addr=".unpack('H*',$addr)."\n");
          ($name, $aliases, $addrtype, $length, @addrs) =
          gethostbyaddr $addr, Socket::AF_INET;
          msg("\ngethostbyaddr $1 RC $? \$!=$!:\n");
          msg("\$aliases=$aliases,\t\@addrs=@addrs\n");
          $host_info{$host}{rDNS} = $name if $?==0;
        } else {
          # look for abuse contacts in abuse.org
          my $domain = $host;

          msg("\nnslookup -type=TXT $domain.contacts.abuse.net\n");
          push @{$host_info{$domain}{DNS}},
               "\nnslookup -type=txt $domain.contacts.abuse.net 2>&1\n";

          # This triggers taint check for $ENV{PATH}
          foreach (`nslookup -type=any $domain.contacts.abuse.net 2>&1`) {
            push @{$host_info{$domain}{DNS}}," $_";
          }

          while ($abusenet) {
            my $key = "$domain.contacts.abuse.net";
            msg("\n\$packet=\$resolver->search($key, TXT)\n");
            my $packet = $resolver->search($key, 'TXT');
            if ($packet) {
#             msg("\nDumper(\$packet)\n");
#             msg(Dumper($packet));
              foreach my $rr ($packet->answer) {
                push @{$host_info{$host}{Email}{$key}}, $rr->char_str_list()
                  if $rr->type eq "TXT";
#               msg("\nDumper(\$rr) for $key TXT\n");
#               msg(Dumper($rr));
              }
              last;
            } elsif ($domain =~ s/^[^.]*\.//) {
              msg("\nTXT RR not found, trying ", $domain, "\n");
              next;
            } else {
              last;
            }
          }
          msg("\nLooking up host name $host at line 1189\n");
          ($name, $aliases, $addrtype, $length, @addrs) =
          gethostbyname($host);
          $aliases //= '';
          msg("\ngethostbyname '$host' RC $? \$!=$!:\n");
#         msg("\$aliases=$aliases,\t\@addrs=@addrs\n");
          msg("\n\$?='$?', \$? == 0=",$? == 0, "\t$?==0 && \$aliases=", $?==0 && $aliases, "\n");
          if ($?==0 && $aliases) {
            $host_info{$host}{CNAME} = $name;
            $host_info{$name}{BASENAME} = $host;
            unshift @{$host_info{$host}{msg}}, ": $host has CNAME $name\n";
            push @{$host_info{$name}{msg}},
                 @{$host_info{$host}{msg}};
            ($name, $aliases, $addrtype, $length, @addrs) =
            gethostbyname($name);
            msg("\ngethostbyname $name CNAME for $host RC $?:\n");
            msg("\$aliases=$aliases\n");
          }
        }
  #     h_errno value   Code  Description
  #     NETDB_INTERNAL  -1    Generic error. Call sock_errno() or
  #                           psock_errno() to get a more detailed
  #                           error code (or error message).
  #     HOST_NOT_FOUND  1
  #     TRY_AGAIN       2
  #     NO_RECOVERY     3
  #     NO_DATA         4
  #     NO_ADDRESS      4
#       msg(Dumper ($name, $aliases, $addrtype, $length, @addrs));
        if (@addrs) {
          my $IPlist;
          msg("\@addrs has ",scalar(@addrs), " entries:\n");
          foreach (@addrs) {
            my $addr = '['.inet_ntoa($_).']';
            msg("\t$host has address $addr\n");
            $host_info{$addr}{isIP}=1;
            push @IP, $addr;
            unless ($host_info{$addr}{URL}) {
              foreach (sort keys %{$host_info{$host}{URL}}) {
                $host_info{$addr}{URL}{$_} = $host_info{$host}{URL}{$_};
              }
            }
          }
          $IPlist = @IP > 1 ? '('.join(', ',sort @IP).')' : $IP[0];
          msg("\$host_info{$host}{IP} = $IPlist\n");
          $host_info{$host}{IP} = $IPlist;
          msg("\$host=$host, \$isIP=$isIP\n");
          next if ($isIP);
          foreach my $URL (sort keys %{$host_info{$host}{URL}}) {
            my $site  = $host_info{$host}{URL}{$URL};
            foreach (@IP) {
              msg("\n\$_=$_\n");
              msg("\$URL=$URL\n");
              msg("\$site=$site\n");
              msg("\$IPlist=$IPlist\n");
              msg("\$_ \$URL \$site \$IPlist $_: $URL at $site $IPlist\n");
              if ($host_info{$host}{spoofed}) {
                push @{$host_info{$_}{msg}},
                     ": possible spam site $URL is at $site $IPlist in your IP space.\n";
              } else {
                push @{$host_info{$_}{msg}},
                     ": spam site $URL is at $site $IPlist in your IP space.\n";
              }
            }
          }
        } elsif ($host_info{$host}{isHELO}) {
          push @{$host_info{$host}{msg}},
               "\nNo DNS information for HELO $host; may be bogus.\n";
          msg("\nNo DNS information for HELO $host.\n");
        }
      }
    }
    msg("\n looping through \%host_info for lookup\n");
    msg("\n sort keys \%host_info = ", sort(keys %host_info), "\n");
    foreach my $host (sort keys %host_info) {
      msg("processing \$host=$host\n");
      print $fhLookup "\n$host:\n";
#     if (my $skipIP=$host_info{$host}{skipIP}) {
#       msg("\t$host is a $skipIP address\n");
#       next;
#     } elsif ($host_info{$host}{NoLookup}) {
#       msg("\t$host is a TLD or RFC 2606 address\n");
#       next;
#     }
      unless ($host_info{$host}{NoLookup}) {
        if ($host_info{$host}{isHELO}) {
          my $IPlist=$host_info{$host}{IP};
          msg("Matching DNS result for HELO $host against source IP.\n");
          foreach my $SMTP (sort keys %{$host_info{$host}{SMTP}}) {
            my $SrcIP=$host_info{$host}{SMTP}{$SMTP};
            msg("\t$SrcIP from $SMTP should be in |$IPlist|\n");
            msg("\t(index \$IPlist, \$SrcIP) is ",index($IPlist, $SrcIP),"\n");
            if (!$IPlist) {
              unshift @{$host_info{$host}{msg}}, "\n\t:$host does not resolve\n"
            } elsif (index($IPlist,$SrcIP) == -1) {
              unshift @{$host_info{$host}{msg}}, "\n\t:$host does not resolve to $SrcIP but to $IPlist\n"
            }
          }
        } elsif (my $SrcIP=$host_info{$host}{SrcIP}) {
          my $IPlist=$host_info{$host}{IP};
          msg("Matching DNS result for rDNS $host against source IP.\n");
          msg("\t$SrcIP should be in $IPlist\n");
          msg("\t(index \$IPlist, \$SrcIP) is ",index($IPlist, $SrcIP),"\n");
          if (!$IPlist) {
            unshift @{$host_info{$host}{msg}}, "\n\t:$host does not resolve\n"
          } elsif (index($IPlist,$SrcIP) == -1) {
            unshift @{$host_info{$host}{msg}}, "\n\t:$host does not resolve to $SrcIP but to $IPlist\n"
          }
        }
        my $isIP = $host_info{$host}{isIP};
        my $key = $host;
        my $NSkey = $host;
        if ($isIP) {
          $host =~/\[ ($IPv4OctetsPat) \]/ox;
          $key = uc $1;
          $NSkey = "$5.$4.$3.$2.in-addr.arpa";
        }

        # store DNS information indented 1 space for label
        push @{$host_info{$host}{DNS}},
             "\nnslookup -type=any $NSkey 2>&1\n";
        # This triggers taint check for $ENV{PATH}
        foreach (`nslookup -type=any $NSkey 2>&1`) {
          push @{$host_info{$host}{DNS}}," $_";
        }

        # generate keys for whois
        my $keys = $key;
        unless ($isIP) {
          $key =~ s/^www\.//io;
          $keys = $key;
          while ($key =~ s/^[^\.]*\.(?=[^\.]*\.)//o) {
            msg("\n\$keys=$keys; trying \$key=$key\n");
            if ($host_info{$key}) {last;}
            $keys = "$keys $key";
            $host_info{$key}{skipwhois}=1;
          }
        }

        # store whois information indented 1 space for label
  #     msg("calling doWhois($host,$keys)\n");
        doWhois($host,$keys);
        #  Note that the line terminator is x'0A' rather than CRLF
        if ($host_info{$host}{Email}) {
          my @abuseContact;
          my @Contact;
          my $email_info = $host_info{$host}{Email};
          foreach (sort keys %{$email_info}) {
            my $email_contact = $email_info->{$_} ;
            push @Contact, @$email_contact;
            push @abuseContact, /abuse/i ? @$email_contact
                                         : grep /abuse/i, @$email_contact;
            msg("host $host tag $_ contact @$email_contact\n");
            msg("host $host tag $_ abuse contact @abuseContact\n");
          }
          if (@abuseContact) {
            print $fhLookup "Abuse contacts: ", join(', ',sortunique(@abuseContact)),"\n";
          } else {
            print $fhLookup "contacts: ", join(', ',sortunique(@Contact)),"\n";
          }
        }
        if ($host_info{$host}{MARF} && $isIP) {
          # This code is based on draft-ietf-marf-reporting-discovery-01.txt
          # Changes may be needed when an RFC is issued.
          # Note that currently the discovery for an IP address is based on
          # the rDNS (PTR) name.
          my $key = "_report.$host";
          msg("\n\$packet = \$resolver->search('$key', 'TXT')\n");
          my $packet = $resolver->search($key, 'TXT');
          if ($packet) {
            foreach my $rr ($packet->answer) {
              msg("ARF discovery for $host:", $rr->rdatastr(), "\n")
              if $rr->type eq "TXT";
            }
          }
          my %MARF_header =(
                            Subject => $head->get('Subject')
             );
  #       my $report = mail::ARF::Report->create(
  #           original_email => $entity,
  #           description    => $MARFdesc,
  #           fields         => \%MARF_fields,
  #           header_str     => \%MARF_header,
  #             );
        }
      }
      foreach (@{$host_info{$host}{msg}}) {
        print $fhLookup "\t$_\n";
      }
      msg("\n\$host=$host for {whois} retrieval.\n");
      print $fhLookup @{$host_info{$host}{whois}}
        if $host_info{$host}{whois};
      print $fhLookup @{$host_info{$host}{DNS}}
        if $host_info{$host}{DNS};
    }
  }
  msg("\nDumper(\%host_info) after lookup\n");
  msg(Dumper(%host_info));

  close($fhLookup) if ($hostinfo);
  $filer->purge if ($cleanup);

}

#   normalize IPv4 address to dressed and find qualifier if local
sub doIP {
  shift =~ /([\d\.]+)/o;
  my $IP = "[$1]";
  my $skipIP= localIP(inet_aton $1);
  $host_info{$IP}{isIP}=1;
  $host_info{$IP}{skipIP}=$skipIP;
  msg("\nDumper(\$skipIP)\n");
  msg(Dumper($skipIP));

  if ($skipIP) {
    $skipIP = "$skipIP IP";
    $host_info{$IP}{skip}="internal $skipIP address $IP";
    $host_info{$IP}{NoLookup}=1;
  } else {
    $skipIP = "IP";
  };
  return ($IP,$skipIP);
}

sub dopart {
  my $part = shift;
  # msg("\nDumper(\$part)\n");
  # msg(Dumper($part));
  use Dumpvalue;
  my $dumper = new Dumpvalue;
  # msg("\n\$dumper->dumpValue(\$part)\n");
  # msg($dumper->dumpValue($part));
  my $head = $part->head;
  my $encoding = $head->mime_encoding;
  my $type = $part->mime_type;
  my $eff_type = $part->effective_type;
  my $bodyh = $part->bodyhandle;
  $part->dump_skeleton;
  unless ($bodyh) {
    msg("No body for this part.\n");
    return unless $eff_type =~ m'^multipart\/'o;
  }
  msg("\$bodyh=$bodyh\n");
  msg("\$type: $type; \$encoding: $encoding\n");
  $_ = $type;
  return if m'^image\/'o;
  if (m'^multipart\/'o) {
    my @subparts        = $part->parts;
    my $num_subparts    = $part->parts;
    msg("\$num_subparts: ",$num_subparts,"\n");
    subpart: foreach my $subpart (@subparts) {
#     msg("\nDumper(\$subpart)\n");
#     msg(Dumper($subpart));
      msg("\ndopart(\$subpart)\n");
      dopart($subpart);
    }
    return;
  }

  my $str = $bodyh->as_string;
  # if CTE was QP then it's already been decoded
  if ($encoding ne 'quoted-printable') {
    $str = decode_qp($str);
  }

  $str = uri_unescape($str);
  # temporary
  # msg("\$str=",Dumper($str));

  while ($str =~ /$URIpat/go) {
    #              preserve results in @+ acress next regex match
    my $URI      = $+{URI};
    my $scheme = uc $+{SCHEME};
    my $host     = $+{HOST};
    my $intIP    = $+{INTIP} // '';
    my $path     = $+{PATH};
    my $query    = $+{QUERY} // '';
    msg("PART URL \$URI=$URI\n");
    msg("PART URL \$scheme=$scheme\n");
    msg("PART URL \$host=$host\n");
    msg("PART URL \$intIP=$intIP\n");
    msg("PART URL \$path=$path\n");
    msg("PART URL \$query=$query\n");
    given ($scheme) {
      when ('FTP') {next}
      when (/HTTPS?/) {
        if ($host) {
          msg("doURI('$URI', '$host', '$intIP', '$path', '$query')\n");
          doURI($URI, $host, $intIP, $path, $query);
        } else {
          msg("\$URI is null\n");
        }
      }
      when ('MAILTO') {
        $path =~ /$mailbox/o;
        msg("doURI('$URI', '$1', '$intIP', '$path', '$query') not called\n");
        # URI syntax require $ encoding of, e.g., plus.
      }
    }
  }

# while ($str =~ /($mailToTag \s* (?: \w+ \s+)*) /xigo) {
#   msg("\$mailToTag matched\n");
#   msg("\$1=$1\n");
# }
# while ($str =~ /($mailbox)/go) {
#   msg("\$mailbox matched\n");
#   msg("\$1=$1\n");
# }
  while ($str =~ /$mailtoPat/go) {
    msg("\$mailtoPat matched\n");
    msg("doURI($+{PSEUDOURI}, $+{HOST}, undef(), '', '')\n");
    doURI($+{PSEUDOURI}, $+{HOST}, undef(), '', '');
  }
}

sub doReceived {
  state $goodIP;
  my ($From, $HELO, $rDNS, $IP, $by1, $by2, $datetime, $For, $ID) = @_;
  msg("\ndoReceived parameters:\n");
  msg("\n\$From     =$From\n");
  msg("\n\$HELO     =$HELO\n");
  msg("\n\$rDNS     =$rDNS\n");
  msg("\n\$IP       =", $IP // '(null)', "\n");
  msg("\n\$by1      =$by1 \n");
  msg("\n\$by2      =$by2 \n");
  msg("\n\$datetime =$datetime \n");
  msg("\n\$For      =$For \n");
  msg("\n\$ID       =", $ID // '(null)', "\n");

  $HELO = uc $HELO;
  $rDNS = uc $rDNS;
  my $intIP;
  if ($IP) {
    $IP     = "[$IP]" unless $IP =~ /\[/o;
    $intIP  = inet_aton substr($IP,2,-1);
    msg("\n\$intIP=".unpack('H*',$intIP)."\n");
  } else {
    msg("\n\$IP and \$intIP undefined\n");
  };
  my $goodHELO;
  if ($prevHELO) {
    msg("\t\$prevHELO=$prevHELO\n");
    msg("\t\$prevSrc=$prevSrc\n");
    unless (uc $by1 eq $prevHELO or
            "\U$by2.$by1" eq $prevHELO or
            uc $by1 eq $prevSrc or
            "\U$by2.$by1" eq $prevSrc) {
      $prevHELO=uc $HELO;
      msg("\t\$prevHELO after mismatch set to $prevHELO\n");
      return undef();
    }
    if ($prevBogus) {
      msg("\tPrevious Received field was bad; skipping $From\n");
      return undef();
    }
  } elsif ($lookup && $MARF) {
    $host_info{$IP}{MARF}=1 if $IP;
    $host_info{$rDNS}{MARF}=1 if $rDNS;
    if ($HELO =~ /^ (?:$addressLiteralPat | $IPv4addressPat | [\w-]++) ^/xo) {
      msg("\nHELO=$HELO is not a FQDN - can't use for MARF\n");
    } else {
      my ($name, $aliases, $addrtype, $length, @addrs) =
         gethostbyname($HELO);
    }
    given ($HELO) {
      when (/$addressLiteralPat/ || /$IPv4addressPat/ || /^[\w-]++$/) {
        msg("\nHLO=$HELO is not a FQDN - can't use for MARF\n");
      }
      when (my $packet = $resolver->search($HELO, 'A')) {
        foreach my $rr ($packet->answer) {
          next if $rr->type ne 'A';
          my $RRIP = $rr->address;
          msg("\n\$IP=$IP, A RR address =", $RRIP, "\n");
          next if '['.$RRIP.']' ne $IP;
          push @MARF_fields, ('Reported-Domain' => $HELO);
        }
      }
    }
    push @MARF_fields, ('Arrival-Date'         => $datetime);
    push @MARF_fields, ('Original-Envelope-Id' => $ID)   if $ID;
    push @MARF_fields, ('Original-Rcpt-To'     => $$For) if $For;
    push @MARF_fields, ('Reported-Domain'      => $HELO) if $HELO ne $rDNS;
    push @MARF_fields, ('Reported-Domain'      => $rDNS) if $rDNS;
    push @MARF_fields, ('Source-IP'            => $IP);
  }
  $prevHELO=$HELO;
  msg("\t\$prevHELO set to $prevHELO\n");
  $prevSrc=$rDNS;
  $prevIP=$IP;

  # Check for loopback or RFC 1918 source IP.
  if (!$IP) {
     msg("\nReceived header field has no source IP address\n");
     return 1;
  }
  my $skipIP = localIP(inet_aton substr $IP, 1, -1);
  $goodIP=$IP unless $skipIP;
  $host_info{$IP}{skipIP}=$skipIP;
  msg("\nDumper(\$skipIP)\n");
  msg(Dumper($skipIP));
  msg("\nDumper(\$goodIP)\n");
  msg(Dumper($goodIP));
  if ($skipIP) {
    push @{$host_info{$goodIP}{msg}},
         ": the spam was routed to $goodIP via $skipIP IP $IP with HELO $HELO\n";
    push @{$host_info{$IP}{msg}},
         ": the spam was routed to $goodIP via $From\n",
         "  $skipIP IP $IP with HELO $HELO\n";
    $host_info{$IP}{SMTP}{$From} = $IP;
    $host_info{$IP}{skip}="internal $skipIP IP address $IP";
    $host_info{$IP}{NoLookup}=1;
    return 1;
  };

  # Set up HELO and sent-from processing.
  $_ = $HELO;
  my $sent;
  $sent = 'the spam was sent from';
  $sent .= ' or relayed by' if /(?:$relayedDom)$/o;

  msg("\nTest HELO $HELO for IP or TLD\n");
  # Don't process HELO/EHLO if it's TLD;
  # validity check if it's IP address.
  my $rDNSeff = $rDNS;
  $rDNSeff =~ s/^\[$RE{net}{IPv4}\]$//o;
  $rDNSeff =~ s/^$RE{net}{IPv4}$//o;
  $rDNSeff =~ s/^[\w-]+$//o;
  msg("\n\$rDNS=$rDNS, \$rDNSeff=$rDNSeff\n");

  if (/^\[$IPv6AddrPat\$]/o) {
    msg("\nHELO $HELO is an IPv6 address.\n");
  } elsif  (/^\[$IPv4addressPat\]$/o || /^$IPv4addressPat$/o) {
    msg("\nHELO $HELO is IPv4 address.\n");
    if ($IP eq $_) {
      msg("\nHELO $HELO is matching and compliant IPv4 address.\n");
      $goodHELO = 1;
    } elsif ($IP eq "[$_]") {
      msg("\nHELO $HELO is matching but noncompliant IPv4 address.\n");
    } else {
      msg("\nHELO $HELO is bogus IPv4 address.\n");
      $prevBogus=1;
    }
    $host_info{$IP}{SMTP}{$rDNSeff.$IP} = $rDNSeff||$IP;
  } elsif (/$RFC2606pat/o) {
    $goodHELO = 1;
    msg("\n\$HELO=$_ is an RFC 2606 subdomain\n");
    $host_info{$_}{skip}='subdomain $_ of RFC 2606 domain $1';
    push @{$host_info{$_}{msg}},
         ": HELO $_ is a subdomain of RFC 2606 domain $1";
    $host_info{$_}{NoLookup}=1;
    $host_info{$HELO}{SMTP}{$From} = $IP;
    push @{$host_info{$HELO}{msg}},
         ": $sent $From\n";
    $host_info{$IP}{SMTP}{$From} = $rDNS;
  } elsif  (/$notTLDpat/o) {
    if  ($rDNS eq $HELO) {
      msg("\nrDNS $rDNS equal HELO $HELO\n");
      $host_info{$IP}{SMTP}{$From} = $rDNS;
    } else {
      $goodHELO = 1;
      $host_info{$HELO}{isHELO} = 1;
      $host_info{$HELO}{SMTP}{$From} = $IP;
      push @{$host_info{$HELO}{msg}},
           ": $sent $From\n";
      $host_info{$IP}{SMTP}{$From} = $rDNS;
    }
  } elsif  (/^[[:alnum:]-]+$/o) {
    if ($rDNS eq $HELO) {
      msg("\nrDNS $rDNS equal HELO $HELO\n");
      $host_info{$IP}{SMTP}{$From} = $rDNS;
    } else {
      $goodHELO = 1;
      msg("\n\$HELO=$_ is a TLD\n");
      $host_info{$_}{skip}="TLD $HELO";
      push @{$host_info{$_}{msg}},
           ": HELO $HELO is a TLD";
      $host_info{$_}{NoLookup}=1;
      $host_info{$HELO}{SMTP}{$From} = $IP;
      push @{$host_info{$HELO}{msg}},
           ": $sent $From\n";
      $host_info{$IP}{SMTP}{$From} = $rDNS;
    }
  } else {
    msg("\nHELO $HELO not valid domain.\n");
    $host_info{$IP}{SMTP}{$rDNSeff.$IP} = $rDNSeff||$IP;
    unshift @{$host_info{$HELO}{msg}}, ": HELO $HELO not valid domain."
  }
  $host_info{$IP}{isIP}          = 1;
  msg("\n\$From from $From\n");
  if ($goodHELO) {
    push @{$host_info{$IP}{msg}},
         ": $sent $From in your IP space.\n";
  } else {
    push @{$host_info{$IP}{msg}},
         ": $sent $rDNSeff $IP in your IP space.\n";
  }
  push @{$host_info{$rDNS}{msg}},
       ": $sent $From\n";
  $host_info{$rDNS}{SrcIP} = $IP;
  $host_info{$rDNS}{SMTP}{$From} = $IP;
  if ($rDNS =~ /$RFC2606pat/o) {
    msg("\n\$rDNS=$rDNS is an RFC 2606 subdomain\n");
    $host_info{$rDNS}{skip}='subdomain $rDNS of RFC 2606 domain $1';
    push @{$host_info{$rDNS}{msg}},
         ": rDNS $rDNS is a subdomain of RFC 2606 domain $1";
    $host_info{$rDNS}{NoLookup}=1;
  } elsif ($rDNS =~ /$notTLDpat/o) {
    msg("\n\$rDNS=$rDNS is a normal domain\n");
  } elsif  (/^[[:alnum:]-]+$/o) {
    msg("\n\$rDNS=$rDNS is a TLD\n");
    $host_info{$rDNS}{skip}="TLD $rDNS";
    push @{$host_info{$rDNS}{msg}},
         ": rDNS $rDNS is a TLD\n";
    $host_info{$rDNS}{NoLookup}=1;
  } else {
    msg("\n\$rDNS=$rDNS is invalid\n");
    $host_info{$rDNS}{skip}="invalid $rDNS";
    push @{$host_info{$rDNS}{msg}},
         ": rDNS $rDNS is invalid\n";
    $host_info{$rDNS}{NoLookup}=1;
  }
  return 1;
}

sub doURI {
  my ($URI, $rawhost, $NumericDomain, $rawPath, $rawQuery, $refURI, $refHost) = @_;
  my $host = uc $rawhost;
  my $path = uc $rawPath;

  msg("\ndoURI(", join(', ',map($_ // "", @_)),")\n");
  if ($NumericDomain) {
    my $intIP = $NumericDomain =~ /^0/o ? oct $NumericDomain :    $NumericDomain;
    msg("\n\$host=$host, \$intIP=$intIP\n");
    return if localIP($intIP);
    $_ = inet_ntoa pack "N", $intIP;
    $host="[$_]";
    msg("\ndoURI \$host=$host\n");
    return if ($host_info{$host}{URL}{$URI});
    $host_info{$host}{URL}{$URI} = $rawhost;
    msg("\nobfuscated host $rawhost is $host in $URI\n");
    msg("\n\$URI \$host $URI at host $host\n");
    push @{$host_info{$host}{msg}},
           ": spam site $URI is at host $host in your IP space.\n";
    $host_info{$host}{isIP} = 1;
  } elsif ($host =~ /$RFC2606pat/o)  {
    msg("\n\$host=$host is an RFC 2606 subdomain\n");
    $host_info{$host}{skip}='subdomain $host of RFC 2606 domain $1';
    push @{$host_info{$host}{msg}},
         ": host $host is a subdomain of RFC 2606 domain $1";
    $host_info{$host}{NoLookup}=1;
    return;
  } elsif ($host =~ /(?:$notTLDpat)/o || $host =~ /(?:$IPv4addressPat)/o) {
    return if $host ~~ ['WWW.W3.ORG', 'WWWW3.ORG'];
    $host =~ s/^$RE{net}{IPv4}{-keep}$/\[$1\]/o;
    $host =~ s/^$RE{net}{IPv4}{-hex}{-keep}{-sep=>""}$/\[$2.$3.$4.$5\]/o;
    msg("\ndoURI \$host=$host.\n");
    $_ = $host;
    unless ($host_info{$_}{URL}{$URI}) {
      msg("\n\$host_info{$_}{URL}{$URI} = $rawhost\n");
      $host_info{$_}{URL}{$URI} = $rawhost;
      if (/^\[[\d\.]*\]$/) {
        msg("\n\$URI \$rawhost \$host $URI at $rawhost $_ in your IP space.\n");
        push @{$host_info{$_}{msg}},
               ": spam site $URI is at $_ in your IP space.\n";
        $host_info{$host}{isIP} = 1;
      } elsif (/(?:$spoofedDom)$/i) {
        msg("\n\$URI \$rawhost \$host : possible spam site $URI is at $host.\n");
        push @{$host_info{$host}{msg}},
               ": possible spam site $URI is at $host.\n";
        $host_info{$host}{spoofed}=1;
      } else {
        msg("\n\$URI \$rawhost \$host : spam site $URI is at $host.\n");
        push @{$host_info{$host}{msg}},
               ": spam site $URI is at $host.\n";
        if ($lookup) {
          msg("\nLooking up MX for $host\n");
          if ($URI =~ /^ (?:E-Mail|Email|mailto|Reply-To) :/iox) {
            my $packet = $resolver->search($host, 'MX');
            if ($packet) {
#             msg("\nDumper(\$packet)\n");
#             msg(Dumper($packet));
              foreach my $rr ($packet->answer) {
                msg("\n\$rr->type=",$rr->type,"\n");
                next unless $rr->type eq 'MX';
                my $MX = $rr->exchange;
                push @{$host_info{$host}{MX}}, $MX;
                push @{$host_info{$MX}{MXof}}, $host;
                push @{$host_info{$host}{msg}},
                       ": $MX is a mail exchange for $host";
                if ($MX ne $host) {
                  $host_info{$MX}{URL}{"$URI MX $MX"} = $MX;
                  push @{$host_info{$MX}{msg}},
                         ": spam site $URI is at $host.\n";
                  push @{$host_info{$MX}{msg}},
                         ": $MX is a mail exchange for $host";
                };
#               msg("\nDumper(\$rr for $host MX\n");
#               msg(Dumper($rr));
              }
            }
          }
        }
      }
      msg("\$_=$_ \$host=$host\n");
      msg("\nDumper(\$host_info{$host})\n");
      msg(Dumper($host_info{$host}),"\n");
    }
  } elsif  (/^[[:alnum:]-]+$/o) {
    msg("\n\$host=$host is a TLD\n");
    $host_info{$host}{skip}="TLD $host";
    push @{$host_info{$host}{msg}},
         ": host $host is a TLD\n";
    $host_info{$host}{NoLookup}=1;
    return;
  } else {
    msg("\n\$host=$host is invalid\n");
    $host_info{$host}{skip}="invalid $host";
    push @{$host_info{$host}{msg}},
         ": host $host is invalid\n";
    $host_info{$host}{NoLookup}=1;
    return;
  }
  if ($refURI) {
    push @{$host_info{$host}{msg}},
           ": referral to $URI is $refURI at $refHost.\n";
  }
  if ($host eq 'WWW.GOOGLE.COM') {
    msg("\nmatching \$path=$path for referral.\n");
    if ($path = 'URL' && $query =~ /Q=$URIpat/o) {
      msg("\n\$path=URL and \$query begins with Q='\n");
      $_ = $+{URI};
      my $subPath = $_;
      msg("\n\$path continues with '$_', hex ",unpack('H*',$_),"\n");
      doURI($+{URI}, $+{HOST}, $+{INTIP}, $+{PATH}, $+{QUERY}, $URI, $host);
    }
  }
}


#     store whois information indented 1 space for label
sub doWhois {
  my ($host, $keys) = @_;
  msg("\ndoWhois $host, $keys\n");
# my $whois = `BWwhois --displaywhois --ripe B --shift 1 --stripdisclaimer --verbose $keys 2>&1\n`;
  my $whois = `BWwhois --displaywhois --ripe B --shift 1 --stripdisclaimer           $keys 2>&1\n`;
  #  Note that the line terminator is x'0A' rather than CRLF
  push @{$host_info{$host}{whois}},
       "\n BWwhois --displaywhois --ripe B --shift 1 --stripdisclaimer $keys 2>&1\n";
  push @{$host_info{$host}{whois}}, $whois;
  my $text = $whois;
  $text =~ s/\x0A/\(LF)/go;
  msg("\n$host \$whois: $text\n");
  msg("\n$host \$whois: ".unpack('H*',$whois)."\n");
  #   Extract contact data.
  $_ = $whois;
  #my $AMTagPat = '((?:(?:[\w-]+\s*)+-?mailbox:))';
  #   if (/\x0A\s*$AMTagPat\s*/gi) {
  #     msg("\nFound contact tag $1\n");
  #   } else {
  #     msg("\nDid not find contact tag\n");
  #   }
  #   if (/\x0A\s*$ContactTagPat\s*/gi) {
  #     msg("\nFound contact tag $1\n");
  #   } else {
  #     msg("\nDid not find contact tag\n");
  #   }
  while (/\R\s*$ContactTagPat\s*(?<!N\/A)([\w\@+\.-]++)/gi) {
    msg(" matched $1 $2\n");
    push @{$host_info{$host}{Email}{$1}}, $2;
  }
  while (/\R\s*(?:Comment:|remarks)\s+
                 (?:Please send\s+)?(:?Abuse\s+)?
                 (?:complaints(?:\/spam report\s+:)?|reports)\s+
                 to\s+([\w\@+\.-]+)/gi) {
    msg(" matched Abuse complaints to $1\n");
    push @{$host_info{$host}{Email}{abuse}}, $1;
  }
  #   while (/\R\s*Comment:\s+Abuse complaints to\s+([\w\@+\.-]+)/gi) {
  #     msg(" matched Abuse complaints to $1\n");
  #     push @{$host_info{$host}{Email}{abuse}}, $1;
  #   }
  #   while (/\R\s*remarks:\s+Please send abuse reports to\s+([\w\@+\.-]+)/gi) {
  #     msg(" matched Please send abuse reports to $1\n");
  #     push @{$host_info{$host}{Email}{abuse}}, $1;
  #   }
  #   Process SWIP records.
  #   Note that nested doWhois call destroys $_
  msg("\n\$_=$_\n");
  while (m'\R\s*([\@\w^&,\./!-]+(?:\s+[\@\w&,\./-]+)*)\s*+\(([\w-]+)\)\s*+\R?\s*+                                                   'gi) {
    msg("\n$host \$1='$1' \$2='$2'         \n");
  }
  my @SWIP;
  while (/$SWIPpat/gi) {
    msg("\n$host [$+{desc},$+{net},$+{IPblock}]\n");
    push @SWIP, [$+{desc},$+{net},$+{IPblock}];
  }
# while (m'\R\s([\@\w^&,\./!-]+(?:\s+[\@\w&,\./-]+)*)\s*+\(([\w-]+)\)\s*+\R?\s*+($IPv4addressPat\s*+-\s*+$IPv4addressPat(?![\d\.]))'gi) {
# while (m'\R\s([\@\w^&,\./!-]+(?:\s+[\@\w&,\./-]+)*)\s*+\(([\w-]+)\)\s*+\R?\s*+($IPv4addressPat\s*+-\s*+$IPv4addressPat          )'gi) {
# #                            --------------------        --------                                                     ----------
# #            --------------------------------------                           ---------------------------------------------------
#   msg("\n$host \$1='$1' \$2='$2' \$3='$3'\n");
#   push @SWIP, [$1,$2,$3];
# }
  foreach $whois (@SWIP) {
    my ($desc,$handle,$IPblock)=@{$whois};
    if ($debug) {
      msg("\nDumper(\%SWIP_DONE) for $handle\n");
      msg(Dumper(%SWIP_DONE),"\n");
    };
    msg("\n$host \$desc='$desc' \$handle='$handle' \$IPblock='$IPblock'\n");
    msg("\$SWIP_DONE{$handle}=", $SWIP_DONE{$handle} // 'undef', "\n");
    unless ($SWIP_DONE{$handle}) {
      push @{$host_info{$host}{whois}},
           "\nNested BWwhois for $desc ($IPblock)\n";
      $SWIP_DONE{$handle} = 1;
      doWhois($host,$handle);
      if ($debug) {
        msg("\nDumper(\%SWIP_DONE) for $handle after set\n");
        msg(Dumper(%SWIP_DONE),"\n");
      };
      #     msg("\$_ after nested doWhois=$_\n");
    };
  }
}

#   Check for IP addresses not routed out of the local network
sub localIP {
  return 'omitted' unless my $binIP = shift;
  my $IP8 = $binIP & $mask8;
  if ($IP8 eq $loopback) {                     # 127/8?
    return 'loopback';
  } elsif ($IP8 eq $RFC1918A                || # 10/8?
           ($binIP & $mask12) eq $RFC1918B  || # 172.16/12?
           ($binIP & $mask16) eq $RFC1918C)    # 192.168/16?
  {
    return "RFC 1918";
  };
  return undef;
}

sub msg {
   if ($debug) { print STDERR @_; }

}

sub sortunique {
  my %key;
  foreach (@_) {
    $key{$_}=1;
  }
  return sort keys %key;
}

1;
__END__

=head1 NAME

unobfuscate - extract domain, IP and URL information

=head1 SYNOPSIS

unobfuscate [options] file ...

 Options:
  --abusenet
  --NOABUSENET
  --CLEANUP
  --nocleanup
  --debug
  --NODEBUG
  --help
  --lookup
  --NOLOOKUP
  --received SkipCount
  --temp path
  --version

=head1 OPTIONS

=over 8

=item B<--abusenet>

Looks up domains in abuse.net

=item B<--cleanup>

Deletes extracted message sections and directories.

=item B<--debug>

Print diagnostic output on STDERR.

=item B<--help>

Print a brief help message and exit.

=item B<--lookup>

Do DNS and WHOIS lookup for each host.

=item B<--MARF>

Create report in RFC 5965 format. Experimental.

=item B<--received> I<SkipCount>

Number of Received: header fields to treat as boilerplate.

=item B<--temp> I<path>

Directory for temporary files

=item B<--version>

Print version information and exit.

=back

=head1 DESCRIPTION

B<unobfuscate> will parse the input files as SMTP messages or
Usenet articles, decode MIME sections, decode QP and %xx
obfuscation and produce a host list sorted by host and URL or
sender. It will recognize a single decimal or hexadecimal number as
the IP address of a host.

=head1 AUTHOR
Shmuel (Seymour J.) Metz <smetz3@gmu.edu>

L<https://mason.gmu.edu/~smetz3>

=head1 COPYRIGHT

Copyright 2006 by Shmuel (Seymour J.) Metz.
L<https://mason.gmu.edu/~smetz3>

I hereby grant a license to anybody to distribute the
unmodified code of this utility.
Modified code may only be distributed if it is provided
in source form and contains no dependencies on closed source
software.

=head1 STABLE

You may obtain the stable version of B<unobfuscate> at
L<https://github.com/shmuelmetz/tools>

=head1 RFC references

=item RFC 1035

DOMAIN NAMES - IMPLEMENTATION AND SPECIFICATION
L<http://www.ietf.org/rfc/rfc1035.txt>

=item RFC 1491

A Survey of Advanced Usages of X.500
L<http://www.ietf.org/rfc/rfc1491.txt>

=item RFC 1918

Address Allocation for Private Internets
L<http://www.ietf.org/rfc/rfc1918.txt>

=item RFC 2045

                 Multipurpose Internet Mail Extensions
                            (MIME) Part One:
                   Format of Internet Message Bodies
L<http://www.ietf.org/rfc/rfc2045.txt>

=item RFC 2396

Uniform Resource Identifiers (URI): Generic Syntax
L<http://www.ietf.org/rfc/rfc2396.txt>

Replaced by RFC 3986.

=item RFC 2606

Reserved Top Level DNS Names
L<http://www.ietf.org/rfc/rfc2606.txt>

=item RFC 3462

                   The Multipart/Report Content Type
                         for the Reporting of
                  Mail System Administrative Messages
L<http://www.ietf.org/rfc/rfc3462.txt>

=item RFC 3986

Uniform Resource Identifier (URI): Generic Syntax
L<http://www.ietf.org/rfc/rfc3986.txt>

=item RFC 2980

Common NNTP Extensions
L<http://www.ietf.org/rfc/rfc2980.txt>

=item RFC 5321

Simple Mail Transfer Protocol
L<http://www.ietf.org/rfc/rfc5321.txt>

=item RFC 5322

Internet Message Format
L<http://www.ietf.org/rfc/rfc5322.txt>

=item RFC 5536

Netnews Article Format
L<http://www.ietf.org/rfc/rfc5536.txt>

=item RFC 5965

An Extensible Format for Email Feedback Reports
L<http://www.ietf.org/rfc/rfc5965.txt>

=item RFC 6650

Creation and Use of Email Feedback Reports:
An Applicability Statement for the Abuse Reporting Format (ARF)
L<http://www.ietf.org/rfc/rfc6650.txt>

=back

=head1 HISTORY

 Revision 0.94 2012-01-15 shmuel
 Added -man option
 Added code to look up contacts in abuse.net
 Added more Received formats
 Added RFC references to POD
 Added note to user in output

 Revision 0.940001 2012-02-15 shmuel
 Made some matches greedy
 Added more Received formats
 Moved subroutines out of loop due to Perl limitation; subroutines
       declared in a loop lose access to my variables in the
       second iteration.
 Added code to parse Return-Path

 Revision 0.940002 2012-03-26 shmuel
 Allowed backtracking in parsing of Received ID
 Allowed msg-id in Received ID without <>

 Revision 0.940003 2015-11-08 shmuel
 Better handling of RFC 1918 addresses, RFC 2606 domains and
 bare top level domains in Received: header fields.
 Miscellaneous enhancements and fixes

 Revision 0.940004 2015-11-15 shmuel
 Look up MX
 Parse invalid URI http://100-00.ru/durable.php

=cut
