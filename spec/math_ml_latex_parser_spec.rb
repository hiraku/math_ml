require "math_ml"
require "spec/util"

describe MathML::LaTeX::Parser do
	include MathML::Spec::Util

	def check_chr(tag, src)
		src.scan(/./) do |c|
			smml(c).should == "<#{tag}>#{c}</#{tag}>"
		end
	end

	def check_hash(tag, hash)
		hash.each do |k, v|
			smml(k).should == "<#{tag}>#{v}</#{tag}>"
		end
	end

	def check_entity(tag, hash)
		check_hash(tag, hash.inject({}){|r, i| r[i[0]]="&#{i[1]};"; r})
	end

	it "Spec#strip_math_ml" do
		src = "<math test='dummy'> <a> b </a> <c> d </c></math>"
		strip_math_ml(src).should == "<a>b</a><c>d</c>"
	end

	describe "#parse" do
		it "should return math element" do
			ns = "http://www.w3.org/1998/Math/MathML"

			e = new_parser.parse("")
			e.should match(EimXML::Element.new(:math, :display=>"inline", "xmlns"=>ns))
			e.attributes.keys.size.should == 2
			e.contents.should be_empty

			e = new_parser.parse("", true)
			e.should match(EimXML::Element.new(:math, :display=>"block", "xmlns"=>ns))
			e.attributes.keys.size.should == 2
			e.contents.should be_empty

			e = new_parser.parse("", false)
			e.should match(EimXML::Element.new(:math, :display=>"inline", "xmlns"=>ns))
			e.attributes.keys.size.should == 2
			e.contents.should be_empty
		end

		it "should ignore space" do
			smml("{ a }").should == "<mrow><mi>a</mi></mrow>"
		end

		it "should process latex block" do
			lambda{smml("test {test} {test")}.should raise_parse_error("Block not closed.", "test {test} ", "{test")
		end

		it "should raise error when error happened" do
			src = 'a\hoge c'
			lambda{smml(src)}.should raise_parse_error("Undefined command.", "a", '\hoge c')

			src = '\sqrt\sqrt1'
			lambda{smml(src)}.should raise_parse_error("Syntax error.", '\sqrt\sqrt', "1")

			src = "a{b"
			lambda{smml(src)}.should raise_parse_error("Block not closed.", "a", "{b")
		end

		it "should process numerics" do
			smml('1234567890').should == "<mn>1234567890</mn>"
			smml('1.2').should == "<mn>1.2</mn>"
			smml('1.').should == "<mn>1</mn><mo>.</mo>"
			smml('.2').should == "<mn>.2</mn>"
			smml('1.2.3').should == "<mn>1.2</mn><mn>.3</mn>"
		end

		it "should process alphabets" do
			smml("abc").should == "<mi>a</mi><mi>b</mi><mi>c</mi>"
			check_chr("mi", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
		end

		it "should process non alphabet command" do
			smml('\,').should == "<mspace width='0.167em' />"
			smml('\|').should == "<mo>&DoubleVerticalBar;</mo>"
		end

		it "should process operators" do
			check_chr("mo", ",.+-*=/()[]|;:!")
			check_entity("mo", {"<"=>"lt", ">"=>"gt", '"'=>"quot"})
			check_hash("mo", {'\backslash'=>'\\', '\%'=>'%', '\{'=>'{', '\}'=>'}', '\$'=>'$', '\#'=>'#'})
		end

		it "should process prime" do
			smml("a'").should == "<msup><mi>a</mi><mo>&prime;</mo></msup>"
			smml("a''").should == "<msup><mi>a</mi><mo>&prime;&prime;</mo></msup>"
			smml("a'''").should == "<msup><mi>a</mi><mo>&prime;&prime;&prime;</mo></msup>"
			smml("'").should == "<msup><none /><mo>&prime;</mo></msup>"

			lambda{smml("a^b'")}.should raise_parse_error("Double superscript.", "a^b", "'")

			smml("a'^b").should == "<msup><mi>a</mi><mrow><mo>&prime;</mo><mi>b</mi></mrow></msup>"
			smml("a'''^b").should == "<msup><mi>a</mi><mrow><mo>&prime;&prime;&prime;</mo><mi>b</mi></mrow></msup>"
			smml("a'b").should == "<msup><mi>a</mi><mo>&prime;</mo></msup><mi>b</mi>"
		end

		it "should process sqrt" do
			smml('\sqrt a').should == "<msqrt><mi>a</mi></msqrt>"
			smml('\sqrt[2]3').should == "<mroot><mn>3</mn><mn>2</mn></mroot>"
			smml('\sqrt[2a]3').should == "<mroot><mn>3</mn><mrow><mn>2</mn><mi>a</mi></mrow></mroot>"
			lambda{smml('\sqrt[12')}.should raise_parse_error("Option not closed.", '\sqrt', "[12")
		end

		it "should process subsup" do
			smml("a_b^c").should == "<msubsup><mi>a</mi><mi>b</mi><mi>c</mi></msubsup>"
			smml("a_b").should == "<msub><mi>a</mi><mi>b</mi></msub>"
			smml("a^b").should == "<msup><mi>a</mi><mi>b</mi></msup>"
			smml("_a^b").should == "<msubsup><none /><mi>a</mi><mi>b</mi></msubsup>"

			lambda{smml("a_b_c")}.should raise_parse_error("Double subscript.", "a_b", "_c")
			lambda{smml("a^b^c")}.should raise_parse_error("Double superscript.", "a^b", "^c")
			lambda{smml("a_")}.should raise_parse_error("Subscript not exist.", "a_", "")
			lambda{smml("a^")}.should raise_parse_error("Superscript not exist.", "a^", "")
		end

		it "should process underover" do
			smml('\sum_a^b', true).should == "<munderover><mo>&sum;</mo><mi>a</mi><mi>b</mi></munderover>"
			smml('\sum_a^b').should == "<msubsup><mo>&sum;</mo><mi>a</mi><mi>b</mi></msubsup>"
			smml('\sum_a', true).should == "<munder><mo>&sum;</mo><mi>a</mi></munder>"
			smml('\sum^a', true).should == "<mover><mo>&sum;</mo><mi>a</mi></mover>"
			smml('\sum_a').should == "<msub><mo>&sum;</mo><mi>a</mi></msub>"
			smml('\sum^a').should == "<msup><mo>&sum;</mo><mi>a</mi></msup>"

			lambda{smml('\sum_b_c')}.should raise_parse_error("Double subscript.", '\sum_b', "_c")
			lambda{smml('\sum^b^c')}.should raise_parse_error("Double superscript.", '\sum^b', "^c")
			lambda{smml('\sum_')}.should raise_parse_error("Subscript not exist.", '\sum_', "")
			lambda{smml('\sum^')}.should raise_parse_error("Superscript not exist.", '\sum^', "")
		end

		it "should process font commands" do
			smml('a{\bf b c}d').should == "<mi>a</mi><mrow><mi mathvariant='bold'>b</mi><mi mathvariant='bold'>c</mi></mrow><mi>d</mi>"
			smml('\bf a{\it b c}d').should == "<mi mathvariant='bold'>a</mi><mrow><mi>b</mi><mi>c</mi></mrow><mi mathvariant='bold'>d</mi>"
			smml('a{\rm b c}d').should == "<mi>a</mi><mrow><mi mathvariant='normal'>b</mi><mi mathvariant='normal'>c</mi></mrow><mi>d</mi>"

			smml('a \mathbf{bc}d').should == "<mi>a</mi><mrow><mrow><mi mathvariant='bold'>b</mi><mi mathvariant='bold'>c</mi></mrow></mrow><mi>d</mi>"
			smml('\mathbf12').should == "<mrow><mn mathvariant='bold'>1</mn></mrow><mn>2</mn>"
			smml('\bf a \mathit{bc} d').should == "<mi mathvariant='bold'>a</mi><mrow><mrow><mi>b</mi><mi>c</mi></mrow></mrow><mi mathvariant='bold'>d</mi>"
			smml('a\mathrm{bc}d').should == "<mi>a</mi><mrow><mrow><mi mathvariant='normal'>b</mi><mi mathvariant='normal'>c</mi></mrow></mrow><mi>d</mi>"

			smml('a \mathbb{b c} d').should == "<mi>a</mi><mrow><mrow><mi>&bopf;</mi><mi>&copf;</mi></mrow></mrow><mi>d</mi>"
			smml('a \mathscr{b c} d').should == "<mi>a</mi><mrow><mrow><mi>&bscr;</mi><mi>&cscr;</mi></mrow></mrow><mi>d</mi>"
			smml('a \mathfrak{b c} d').should == "<mi>a</mi><mrow><mrow><mi>&bfr;</mi><mi>&cfr;</mi></mrow></mrow><mi>d</mi>"
			smml('a \bm{bc}d').should == "<mi>a</mi><mrow><mrow><mi mathvariant='bold-italic'>b</mi><mi mathvariant='bold-italic'>c</mi></mrow></mrow><mi>d</mi>"
			smml('\bm ab').should == "<mrow><mi mathvariant='bold-italic'>a</mi></mrow><mi>b</mi>"

			lambda{smml('\mathit')}.should raise_parse_error("Syntax error.", '\mathit', "")
			lambda{smml('\mathrm')}.should raise_parse_error("Syntax error.", '\mathrm', "")
			lambda{smml('\mathbf')}.should raise_parse_error("Syntax error.", '\mathbf', "")
			lambda{smml('\mathbb')}.should raise_parse_error("Syntax error.", '\mathbb', "")
			lambda{smml('\mathscr')}.should raise_parse_error("Syntax error.", '\mathscr', "")
			lambda{smml('\mathfrak')}.should raise_parse_error("Syntax error.", '\mathfrak', "")
		end

		it "should process mbox" do
			smml('a\mbox{b c}d').should == "<mi>a</mi><mtext>b c</mtext><mi>d</mi>"
			smml('\mbox{<>\'"&}').should == '<mtext>&lt;&gt;&apos;&quot;&amp;</mtext>'
		end

		it "should process frac" do
			smml('\frac ab').should == "<mfrac><mi>a</mi><mi>b</mi></mfrac>"
			smml('\frac12').should == "<mfrac><mn>1</mn><mn>2</mn></mfrac>"

			lambda{smml('\frac a')}.should raise_parse_error("Syntax error.", '\frac a', "")
		end

		it "should process environment" do
			lambda{smml('{\begin}rest')}.should raise_parse_error("Environment name not exist.", '{\begin', '}rest')

			lambda{smml('{\begin{array}{c}dummy}rest')}.should raise_parse_error('Matching \end not exist.', '{\begin{array}{c}dummy', '}rest')

			lambda{smml('\begin{array}c dummy\end{test}')}.should raise_parse_error("Environment mismatched.", '\begin{array}c dummy\end', "{test}")

			lambda{smml('\left(\begin{array}\right)')}.should raise_parse_error("Syntax error.", '\left(\begin{array}', '\right)')
		end

		it "should process array" do
			smml('\begin{array}{lrc} a & b & c \\\\ d & e & f \\\\ \end{array}').should == "<mtable columnalign='left right center'><mtr><mtd><mi>a</mi></mtd><mtd><mi>b</mi></mtd><mtd><mi>c</mi></mtd></mtr><mtr><mtd><mi>d</mi></mtd><mtd><mi>e</mi></mtd><mtd><mi>f</mi></mtd></mtr></mtable>"

			smml('\begin{array}{lrc}a&b&c\\\\d&e&f \end{array}').should == "<mtable columnalign='left right center'><mtr><mtd><mi>a</mi></mtd><mtd><mi>b</mi></mtd><mtd><mi>c</mi></mtd></mtr><mtr><mtd><mi>d</mi></mtd><mtd><mi>e</mi></mtd><mtd><mi>f</mi></mtd></mtr></mtable>"

			smml('\begin{array}{c}\end{array}').should == "<mtable />"

			lambda{smml('\begin{array}\end{array}')}.should raise_parse_error('Syntax error.', '\begin{array}', '\end{array}')

			lambda{smml('\begin{array}{a}\end{array}')}.should raise_parse_error("Syntax error.", '\begin{array}{', 'a}\end{array}')

			lambda{smml('\begin{array}{cc}a\\\\b&c\end{array}')}.should raise_parse_error("Need more column.", '\begin{array}{cc}a', '\\\\b&c\end{array}')

			lambda{smml('\begin{array}{cc}a\end{array}')}.should raise_parse_error("Need more column.", '\begin{array}{cc}a', '\end{array}')

			lambda{smml('\begin{array}{c}a&\end{array}')}.should raise_parse_error("Too many column.", '\begin{array}{c}a', '&\end{array}')

			smml('\begin{array}{cc}&\end{array}').should == "<mtable><mtr><mtd /><mtd /></mtr></mtable>"

			smml('\left\{\begin{array}ca_b\end{array}\right\}').should == "<mfenced close='}' open='{'><mrow><mtable><mtr><mtd><msub><mi>a</mi><mi>b</mi></msub></mtd></mtr></mtable></mrow></mfenced>"

			smml('\begin{array}{@{a_1}l@bc@cr@d}A&B&C\end{array}').should == "<mtable columnalign='center left center center center right center'><mtr><mtd><mrow><msub><mi>a</mi><mn>1</mn></msub></mrow></mtd><mtd><mi>A</mi></mtd><mtd><mi>b</mi></mtd><mtd><mi>B</mi></mtd><mtd><mi>c</mi></mtd><mtd><mi>C</mi></mtd><mtd><mi>d</mi></mtd></mtr></mtable>"

			smml('\left\{\begin{array}ca_b\end{array}\right\}').should == "<mfenced close='}' open='{'><mrow><mtable><mtr><mtd><msub><mi>a</mi><mi>b</mi></msub></mtd></mtr></mtable></mrow></mfenced>"

			smml('\begin{array}{c|c}a&b\\\\c&d\end{array}').should == "<mtable columnlines='solid'><mtr><mtd><mi>a</mi></mtd><mtd><mi>b</mi></mtd></mtr><mtr><mtd><mi>c</mi></mtd><mtd><mi>d</mi></mtd></mtr></mtable>"
			smml('\begin{array}{|c|}a\\\\c\end{array}').should == "<mtable columnlines='solid solid'><mtr><mtd /><mtd><mi>a</mi></mtd><mtd /></mtr><mtr><mtd /><mtd><mi>c</mi></mtd><mtd /></mtr></mtable>"
			smml('\begin{array}{c}\hline c\end{array}').should == "<mtable rowlines='solid'><mtr /><mtr><mtd><mi>c</mi></mtd></mtr></mtable>"
			smml('\begin{array}{c@acc}c&c&c\\\\\hline\end{array}').should == "<mtable rowlines='solid'><mtr><mtd><mi>c</mi></mtd><mtd><mi>a</mi></mtd><mtd><mi>c</mi></mtd><mtd><mi>c</mi></mtd></mtr><mtr><mtd /><mtd /><mtd /><mtd /></mtr></mtable>"
			smml('\begin{array}{c}\hline a\\\\b\\\\\hline\end{array}').should == "<mtable rowlines='solid none solid'><mtr /><mtr><mtd><mi>a</mi></mtd></mtr><mtr><mtd><mi>b</mi></mtd></mtr><mtr><mtd /></mtr></mtable>"
		end

		it "should parse \\left and \\right" do
			smml('\left(\frac12\right)').should == "<mfenced close=')' open='('><mrow><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></mfenced>"

			smml('\left \lfloor a\right \rfloor').should == "<mfenced close='&rfloor;' open='&lfloor;'><mrow><mi>a</mi></mrow></mfenced>"

			smml('\left \{ a \right \}').should == "<mfenced close='}' open='{'><mrow><mi>a</mi></mrow></mfenced>"

			smml('\left\{\begin{array}c\begin{array}ca\end{array}\end{array}\right\}').should == "<mfenced close='}' open='{'><mrow><mtable><mtr><mtd><mtable><mtr><mtd><mi>a</mi></mtd></mtr></mtable></mtd></mtr></mtable></mrow></mfenced>"

			smml('\left(\sum_a\right)').should == "<mfenced close=')' open='('><mrow><msub><mo>&sum;</mo><mi>a</mi></msub></mrow></mfenced>"
			smml('\left(\sum_a\right)', true).should == "<mfenced close=')' open='('><mrow><munder><mo>&sum;</mo><mi>a</mi></munder></mrow></mfenced>"

			lambda{smml('\left(test')}.should raise_parse_error("Brace not closed.", '\left', '(test')

			smml('\left\|a\right\|').should == "<mfenced close='&DoubleVerticalBar;' open='&DoubleVerticalBar;'><mrow><mi>a</mi></mrow></mfenced>"

			lambda{smml('\left')}.should raise_parse_error("Need brace here.", '\left', "")
		end

		it "should parse overs" do
			smml('\hat a').should == "<mover><mi>a</mi><mo>&circ;</mo></mover>"
			smml('\hat12').should == "<mover><mn>1</mn><mo>&circ;</mo></mover><mn>2</mn>"
			lambda{smml('{\hat}a')}.should raise_parse_error("Syntax error.", '{\hat', '}a')
		end

		it "should parse unders" do
			smml('\underline a').should == "<munder><mi>a</mi><mo>&macr;</mo></munder>"
			smml('\underline12').should == "<munder><mn>1</mn><mo>&macr;</mo></munder><mn>2</mn>"
			lambda{smml('{\underline}a')}.should raise_parse_error("Syntax error.", '{\underline', '}a')
		end

		it "should parse stackrel" do
			smml('\stackrel\to=').should == "<mover><mo>=</mo><mo>&rightarrow;</mo></mover>"
			smml('\stackrel12').should == "<mover><mn>2</mn><mn>1</mn></mover>"
		end

		it "should parse comment" do
			smml('a%b').should == "<mi>a</mi>"
		end

		it "should parse entity" do
			p = new_parser
			lambda{smml('\entity{therefore}', false, p)}.should raise_parse_error("Unregistered entity.", '\entity{', "therefore}")

			p.unsecure_entity = true
			smml('\entity{therefore}', false, p).should == "<mo>&therefore;</mo>"

			p.unsecure_entity = false
			lambda{smml('\entity{therefore}', false, p)}.should raise_parse_error("Unregistered entity.", '\entity{', "therefore}")

			p.add_entity(['therefore'])
			smml('\entity{therefore}', false, p).should == "<mo>&therefore;</mo>"
		end

		it "should parse backslash" do
			smml('\\\\').should == "<br xmlns='http://www.w3.org/1999/xhtml' />"
		end

		it "can be used with macro" do
			macro = <<'EOS'
\newcommand{\root}[2]{\sqrt[#1]{#2}}
\newcommand{\ROOT}[2]{\sqrt[#1]#2}
\newenvironment{braced}[2]{\left#1}{\right#2}
\newenvironment{sq}[2]{\sqrt[#2]{#1}}{\sqrt#2}
\newcommand{\R}{\mathbb R}
\newenvironment{BB}{\mathbb A}{\mathbb B}
EOS
			p = new_parser
			p.macro.parse(macro)

			smml('\root12', false, p).should == "<mroot><mrow><mn>2</mn></mrow><mn>1</mn></mroot>"
			smml('\root{12}{34}', false, p).should == "<mroot><mrow><mn>34</mn></mrow><mn>12</mn></mroot>"
			smml('\ROOT{12}{34}', false, p).should == "<mroot><mn>3</mn><mn>12</mn></mroot><mn>4</mn>"
			lambda{smml('\root', false, p)}.should raise_parse_error('Error in macro(Need more parameter. "").', '', '\root')

			smml('\begin{braced}{|}{)}\frac12\end{braced}', false, p).should == "<mfenced close=')' open='|'><mrow><mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></mfenced>"
			smml('\begin{sq}{12}{34}a\end{sq}', false, p).should == "<mroot><mrow><mn>12</mn></mrow><mn>34</mn></mroot><mi>a</mi><msqrt><mn>3</mn></msqrt><mn>4</mn>"
			lambda{smml('\begin{braced}', false, p)}.should raise_parse_error("Need more parameter.", '\begin{braced}', "")
			lambda{smml('\begin{braced}123', false, p)}.should raise_parse_error('Matching \end not exist.', '\begin{braced}', "123")
			lambda{smml('\begin{braced}123\end{brace}', false, p)}.should raise_parse_error("Environment mismatched.", '\begin{braced}123\end', '{brace}')
			smml('\R', false, p).should == "<mrow><mi>&Ropf;</mi></mrow>"
			smml('\begin{BB}\end{BB}', false, p).should == "<mrow><mi>&Aopf;</mi></mrow><mrow><mi>&Bopf;</mi></mrow>"
		end

		it "should raise error when macro define circular reference" do
			macro = <<'EOT'
\newcommand{\C}{\C}
\newenvironment{E}{\begin{E}}{\end{E}}
\newcommand{\D}{\begin{F}\end{F}}
\newenvironment{F}{\D}{}
EOT
			ps = new_parser
			ps.macro.parse(macro)

			lambda{smml('\C', false, ps)}.should raise_parse_error("Circular reference.", "", '\C')
			lambda{smml('\begin{E}\end{E}', false, ps)}.should raise_parse_error("Circular reference.", "", '\begin{E}\end{E}')
			lambda{smml('\D', false, ps)}.should raise_parse_error("Circular reference.", "", '\D')
			lambda{smml('\begin{F}\end{F}', false, ps)}.should raise_parse_error("Circular reference.", "", '\begin{F}\end{F}')
		end

		it "should raise error when macro uses undefined command" do
			macro = <<'EOT'
\newcommand{\C}{\dummy}
\newenvironment{E}{\dummy}{}
EOT
			ps = new_parser
			ps.macro.parse(macro)

			lambda{smml('\C', false, ps)}.should raise_parse_error('Error in macro(Undefined command. "\dummy").', "", '\C')
			lambda{smml('\C', false, ps)}.should raise_parse_error('Error in macro(Undefined command. "\dummy").', "", '\C')

			lambda{smml('\begin{E}\end{E}', false, ps)}.should raise_parse_error('Error in macro(Undefined command. "\dummy").', '', '\begin{E}\end{E}')
			lambda{smml('\begin{E}\end{E}', false, ps)}.should raise_parse_error('Error in macro(Undefined command. "\dummy").', "", '\begin{E}\end{E}')
		end

		it "can be used with macro with option" do
			macro = <<'EOS'
\newcommand{\opt}[1][x]{#1}
\newcommand{\optparam}[2][]{#1#2}
\newenvironment{newenv}[1][x]{#1}{#1}
\newenvironment{optenv}[2][]{#1}{#2}
EOS

			p = new_parser
			p.macro.parse(macro)

			smml('\opt a', false, p).should == "<mi>x</mi><mi>a</mi>"
			smml('\opt[0] a', false, p).should == "<mn>0</mn><mi>a</mi>"
			smml('\optparam a', false, p).should == "<mi>a</mi>"
			smml('\optparam[0] a', false, p).should == "<mn>0</mn><mi>a</mi>"

			smml('\begin{newenv}a\end{newenv}', false, p).should == "<mi>x</mi><mi>a</mi><mi>x</mi>"
			smml('\begin{newenv}[0]a\end{newenv}', false, p).should == "<mn>0</mn><mi>a</mi><mn>0</mn>"
			smml('\begin{optenv}0a\end{optenv}', false, p).should == "<mi>a</mi><mn>0</mn>"
			smml('\begin{optenv}[0]1a\end{optenv}', false, p).should == "<mn>0</mn><mi>a</mi><mn>1</mn>"
		end

		it "should parse matrix environment" do
			smml('\begin{matrix}&&\\\\&\end{matrix}').should == "<mtable><mtr><mtd /><mtd /><mtd /></mtr><mtr><mtd /><mtd /></mtr></mtable>"
			lambda{smml('\begin{matrix}&&\\\\&\end{mat}')}.should raise_parse_error("Environment mismatched.", '\begin{matrix}&&\\\\&\end', "{mat}")
			lambda{smml('\begin{matrix}&&\\\\&')}.should raise_parse_error("Matching \\end not exist.", '\begin{matrix}&&\\\\&', '')
			smml('\begin{matrix}\begin{matrix}a&b\\\\c&d\end{matrix}&1\\\\0&1\\\\\end{matrix}').should == "<mtable><mtr><mtd><mtable><mtr><mtd><mi>a</mi></mtd><mtd><mi>b</mi></mtd></mtr><mtr><mtd><mi>c</mi></mtd><mtd><mi>d</mi></mtd></mtr></mtable></mtd><mtd><mn>1</mn></mtd></mtr><mtr><mtd><mn>0</mn></mtd><mtd><mn>1</mn></mtd></mtr></mtable>"
			smml('\begin{matrix}\end{matrix}').should == "<mtable />"
			smml('\begin{matrix}\hline a\\\\b\\\\\hline\end{matrix}').should == "<mtable rowlines='solid none solid'><mtr /><mtr><mtd><mi>a</mi></mtd></mtr><mtr><mtd><mi>b</mi></mtd></mtr><mtr /></mtable>"

			smml('\begin{smallmatrix}\end{smallmatrix}').should == "<mtable />"
			smml('\begin{pmatrix}\end{pmatrix}').should == "<mfenced close=')' open='('><mrow><mtable /></mrow></mfenced>"
			smml('\begin{bmatrix}\end{bmatrix}').should == "<mfenced close=']' open='['><mrow><mtable /></mrow></mfenced>"
			smml('\begin{Bmatrix}\end{Bmatrix}').should == "<mfenced close='}' open='{'><mrow><mtable /></mrow></mfenced>"
			smml('\begin{vmatrix}\end{vmatrix}').should == "<mfenced close='|' open='|'><mrow><mtable /></mrow></mfenced>"
			smml('\begin{Vmatrix}\end{Vmatrix}').should == "<mfenced close='&DoubleVerticalBar;' open='&DoubleVerticalBar;'><mrow><mtable /></mrow></mfenced>"
		end

		it "can be used in safe mode" do
			Thread.start do
				$SAFE=1
				$SAFE.should == 1
				lambda{smml('\alpha'.taint)}.should_not raise_error
			end.join

			$SAFE.should == 0
		end

		it "should parse symbols" do
			smml('\precneqq').should == "<mo><mfrac linethickness='0' mathsize='1%'><mo>&prec;</mo><mo>&ne;</mo></mfrac></mo>"
		end
	end
end