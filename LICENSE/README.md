# LICENSE

The Mecrisp PI processor is a basically a Mecrisp Ice 2.6d, which is a
variant of SwapForth.  (Mecrisp Ice 2.6e does not have a license.)
Both SwapForth and Mecrisp Ice 2.6d are based on the FreeBSD 3 clause
license.  So the underlying Verilog is only subject to the FreeBSD
3 clause license.

But the FreeBSD license has not worked out well for either SwapForth
nor Mecrisp Ice.  Both are out of date and need some serious
investment.  They needed to be ported to the newest version of YOSYS,
they needed to be ported to the newer ICE40 UP5k chips, Mecrisp badly
needed documentation.  So this software is being released under the
Business Source License. If you are a hobbyist, you can use it for
free. In 4 years it goes GPL.  If you are making money off of it, it
is only fair to share some of that money, so let us talk.  And since
the Business Source license is based on GPL, and GPL does not work
well for hardware, the Verilog is also available in 4 years under the
CERN Open Hardware Licence Version 2 – Strongly Reciprocal License.

Both SwapForth and Mecrisp Ice use gForth to do cross compiling.  And
the cross compiled code will soon be included in the gateware.  So the
Forth code is subject to the FreeBSD license, but it may or may not
also be subject to the GPL license.  That depends on whether any part
of gForth is included in the cross compiled code.  Since the cross
compiler is so difficult to understand, I am not yet sure of the
answer.  I used to think it was, on closer reading of the source code,
I now think that it is not.

I am not a lawyer, this is not legal advice.

