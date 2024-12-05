from parsimonious.grammar import Grammar
from parsimonious.nodes import NodeVisitor

grammar = Grammar(
    r"""
    expr        = (reginstr / emptyline)*
    reginstr    = sizecl comma offsetcl comma datacl

    sizecl      = sizekey colon hexnumber
    sizekey     = "Size"
    offsetcl    = offsetkey colon hexnumber
    offsetkey   = "Offset"
    datacl      = datakey colon hexnumber
    datakey     = "Data"

    hexnumber   = hexprefix? hexpattern+
    hexprefix   = (hexprefixl / hexprefixu)
    hexprefixl  = "0x"
    hexprefixu  = "0X"
    hexpattern  = ~r"[0-9a-fA-F]"

    colon       = ws? ":" ws?
    comma       = ws? "," ws?
    ws          = ~r"\s*"
    emptyline   = ws+
    """
)

class IDT8A34XXXVisitor(NodeVisitor):
    def visit_expr(self, node, visited_children):
        """ Returns the overall output """

        output = []

        for child in visited_children:
            if child[0] is not None:
                output.append(child[0])

        return output

    def visit_reginstr(self, node, visited_children):
        """ Makes a dictionary of a register instruction """
        sizecl, _,  offsetcl, _, datacl = visited_children
        return dict((k, v) for k, v in (sizecl, offsetcl, datacl))

    def visit_sizecl(self, node, visited_children):
        """ Gets the size clause key/value pair, return a tuple """
        key, _, value = node.children
        return key.text, value.text

    def visit_offsetcl(self, node, visited_children):
        """ Gets the offset clause key/value pair, return a tuple """
        key, _, value = node.children
        return key.text, value.text

    def visit_datacl(self, node, visited_children):
        """ Gets the data clause key/value pair, return a tuple """
        key, _, value = node.children
        return key.text, value.text

    def visit_emptyline(self, node, visited_children):
        """ Consume emptyline """
        pass

    def visit_commentline(self, node, visited_children):
        """ Consume commentline """
        pass

    def generic_visit(self, node, visited_children):
        """ The generic visit method. """
        return visited_children or node

idt_data = """



Size: 0x4, Offset: FC, Data: 0x00C01020
Size: 0x4, Offset: FC, Data: 0x00811020
Size: 0x4, Offset: FC, Data: 0x00C11020
Size: 0x2, Offset: 60, Data: 0x0000
Size: 0x6, Offset: 64, Data: 0x000000000000
Size: 0x2, Offset: 6C, Data: 0x0000
Size: 0x8, Offset: 70, Data: 0x0000000000000000
Size: 0x13, Offset: 80, Data: 0x00000000000000000000000000000000000000
Size: 0x1A, Offset: 94, Data: 0x00B0710B000005000000000000000000800648F63703FFFF7D40
Size: 0xE, Offset: B0, Data: 0x00E1F50500000000010000000001
Size: 0xE, Offset: C0, Data: 0x0000000000000000000000000100
Size: 0xE, Offset: D0, Data: 0x0000000000000000000000000200
Size: 0x4, Offset: FC, Data: 0x00C21020
Size: 0xE, Offset: 00, Data: 0x0000000000000000000000000300
Size: 0xE, Offset: 10, Data: 0x0000000000000000000000000400
Size: 0xE, Offset: 20, Data: 0x0000000000000000000000000500
Size: 0xE, Offset: 30, Data: 0x0000000000000000000000000600
Size: 0xE, Offset: 40, Data: 0x0000000000000000000000000700
Size: 0xE, Offset: 50, Data: 0x0000000000000000000000000800
Size: 0xE, Offset: 60, Data: 0x0000000000000000000000000900
Size: 0xE, Offset: 80, Data: 0x0000000000000000000000000A00
Size: 0xE, Offset: 90, Data: 0x0000000000000000000000000B00
Size: 0xE, Offset: A0, Data: 0x0000000000000000000000000C00
Size: 0xE, Offset: B0, Data: 0x0000000000000000000000000D00
Size: 0xE, Offset: C0, Data: 0x0000000000000000000000000E00
Size: 0xE, Offset: D0, Data: 0x0000000000000000000000000F00
Size: 0x7, Offset: E0, Data: 0x00000000000000
Size: 0xB, Offset: E8, Data: 0x0000000300000000000000
Size: 0x4, Offset: F4, Data: 0x00000000
Size: 0x4, Offset: FC, Data: 0x00C31020
Size: 0x7, Offset: 00, Data: 0x00000000000000
Size: 0xB, Offset: 08, Data: 0x0000000000000000000000
Size: 0xB, Offset: 14, Data: 0x0000000000000000000000
Size: 0xB, Offset: 20, Data: 0x0000000000000000000000
Size: 0xB, Offset: 2C, Data: 0x0000000000000000000000
Size: 0xB, Offset: 38, Data: 0x0000000000000000000000
Size: 0xB, Offset: 44, Data: 0x0000000000000000000000
Size: 0xB, Offset: 50, Data: 0x0000000000000000000000
Size: 0xB, Offset: 5C, Data: 0x0000000000000000000000
Size: 0xB, Offset: 68, Data: 0x0000000000000000000000
Size: 0x4, Offset: 74, Data: 0x00000000
Size: 0x7, Offset: 80, Data: 0x00000000000000
Size: 0xB, Offset: 88, Data: 0x0000000000000000000000
Size: 0xB, Offset: 94, Data: 0x0000000000000000000000
Size: 0xB, Offset: A0, Data: 0x0000000000000000000000
Size: 0x3C, Offset: AC, Data: 0x0000000000000402000000000000000A0100000000000000000000000000000000000000000000000000000000000000000000000000080800000000
Size: 0x4, Offset: FC, Data: 0x00C41020
Size: 0x70, Offset: 00, Data: 0x00000000000000000000000A010000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000400000000000000000A0100000000000000000000000000000000000000000000000000000000000000000000000000000000010000
Size: 0x70, Offset: 80, Data: 0x00000000000000000000000A010000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000A0100000000000000000000000000000000000000000000000000000000000000000000000000000000010000
Size: 0x4, Offset: FC, Data: 0x00C51020
Size: 0x70, Offset: 00, Data: 0x00000000000000000000000A010000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000A0100000000000000000000000000000000000000000000000000000000000000000000000000000000010000
Size: 0x55, Offset: 80, Data: 0x00000000000000000000000A01000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000A01000025000000000000000000000000000000000000000000
Size: 0x4, Offset: FC, Data: 0x00C61020
Size: 0x2E, Offset: 00, Data: 0x00000004198000000000000000000000000000000000000000000000009B3247CD1DFFFF05000000000000000000
Size: 0x3A, Offset: 30, Data: 0x000000000000A12A0000000000000004198000000000000000000000000000000000000000000000C041FF984025FFFF64000000000000000000
Size: 0xC, Offset: 6C, Data: 0x000000000000A12A00000000
Size: 0x2E, Offset: 80, Data: 0x00000004198000000000000000000000000000000000000000000000C041FF984025FFFF64000000000000000000
Size: 0x3A, Offset: B0, Data: 0x000000000000A12A0000000000000004198000000000000000000000000000000000000000000000C041FF984025FFFF64000000000000000000
Size: 0xC, Offset: EC, Data: 0x000000000000A12A00000000
Size: 0x4, Offset: FC, Data: 0x00C71020
Size: 0x2E, Offset: 00, Data: 0x00000004198000000000000000000000000000000000000000000000000000000000000000000000000000000000
Size: 0x3A, Offset: 30, Data: 0x000000000000A12A0000000000000004198000000000000000000000000000000000000000000000C041FF984025FFFF64000000000000000000
Size: 0xC, Offset: 6C, Data: 0x000000000000A12A00000000
Size: 0x2E, Offset: 80, Data: 0x00000004198000000000000000000000000000000000000000000000C041FF984025FFFF64000000000000000000
Size: 0x3A, Offset: B0, Data: 0x000000000000A12A0000000000000004198000000000000000000000000000000000000000000000000000000000000000000000000000000000
Size: 0xC, Offset: EC, Data: 0x000000000000A12A00000000
Size: 0x4, Offset: FC, Data: 0x00C81020
Size: 0x3, Offset: 00, Data: 0x000004
Size: 0x13, Offset: 04, Data: 0x64800000000000000000000000000000000000
Size: 0x60, Offset: 18, Data: 0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
Size: 0x41, Offset: 80, Data: 0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
Size: 0x11, Offset: C2, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: D4, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: E6, Data: 0x0000000000000000000000000000000000
Size: 0x4, Offset: FC, Data: 0x00C91020
Size: 0x11, Offset: 00, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: 12, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: 24, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: 36, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: 48, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: 5A, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: 80, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: 92, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: A4, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: B6, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: C8, Data: 0x0000000000000000000000000000000000
Size: 0x11, Offset: DA, Data: 0x0000000000000000000000000000000000
Size: 0x4, Offset: FC, Data: 0x00CA1020
Size: 0x11, Offset: 00, Data: 0x0000000000000000000000000000000000
Size: 0xC, Offset: 12, Data: 0x010105000000000000004120
Size: 0xE, Offset: 20, Data: 0x0000000005000000000000004120
Size: 0xE, Offset: 30, Data: 0x0000000004000000000000004120
Size: 0xE, Offset: 40, Data: 0x0000000004000000000000004120
Size: 0xE, Offset: 50, Data: 0x0000000004000000000000004120
Size: 0xE, Offset: 60, Data: 0x0000000004000000000000004120
Size: 0x4, Offset: 70, Data: 0x00000000
Size: 0xA, Offset: 80, Data: 0x04000000000000004120
Size: 0xE, Offset: 8C, Data: 0x0000000004000000000000004120
Size: 0xE, Offset: 9C, Data: 0x0000000004000000000000004120
Size: 0xE, Offset: AC, Data: 0x0000000004000000000000004120
Size: 0xE, Offset: BC, Data: 0x0000000004000000000000004120
Size: 0xE, Offset: CC, Data: 0x0000000004000000000000004120
Size: 0xD, Offset: DC, Data: 0x00000000000000000000000000
Size: 0x4, Offset: FC, Data: 0x00CB1020
Size: 0x5, Offset: 00, Data: 0x0000000000
Size: 0x5, Offset: 08, Data: 0x0000000000
Size: 0x5, Offset: 10, Data: 0x0000000000
Size: 0x5, Offset: 18, Data: 0x0000000000
Size: 0x5, Offset: 20, Data: 0x0000000000
Size: 0x5, Offset: 28, Data: 0x0000000000
Size: 0x5, Offset: 30, Data: 0x0000000000
Size: 0x5, Offset: 38, Data: 0x0000000000
Size: 0x6, Offset: 40, Data: 0x000000000000
Size: 0x6, Offset: 48, Data: 0x000000000000
Size: 0x6, Offset: 50, Data: 0x000000000000
Size: 0x6, Offset: 58, Data: 0x000000000000
Size: 0x6, Offset: 60, Data: 0x000000000000
Size: 0x6, Offset: 68, Data: 0x000000000000
Size: 0x6, Offset: 70, Data: 0x000000000000
Size: 0x6, Offset: 80, Data: 0x000000000000
Size: 0x6, Offset: 88, Data: 0x000000000000
Size: 0x6, Offset: 90, Data: 0x000000000000
Size: 0x6, Offset: 98, Data: 0x000000000000
Size: 0x6, Offset: A0, Data: 0x000000000000
Size: 0x6, Offset: A8, Data: 0x000000000000
Size: 0x6, Offset: B0, Data: 0x000000000000
Size: 0x6, Offset: B8, Data: 0x000000000000
Size: 0x6, Offset: C0, Data: 0x000000000000
Size: 0x5, Offset: C8, Data: 0x0000000000
Size: 0x1, Offset: CE, Data: 0x00
Size: 0x1, Offset: D0, Data: 0x00
Size: 0x1, Offset: D2, Data: 0x00
Size: 0x4, Offset: FC, Data: 0x00CC1020
Size: 0x4F, Offset: 00, Data: 0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
Size: 0xF, Offset: 50, Data: 0x000000000000000000000000000000
Size: 0xF, Offset: 60, Data: 0x000000000000000000000000000000
Size: 0xF, Offset: 80, Data: 0x000000000000000000000000000000
Size: 0xF, Offset: 90, Data: 0x000000000000000000000000000000
Size: 0xF, Offset: A0, Data: 0x000000000000000000000000000000
Size: 0xF, Offset: B0, Data: 0x000000000000000000000000000000
Size: 0xF, Offset: C0, Data: 0x000000000000000000000000000000
Size: 0x5, Offset: D0, Data: 0x0000000000
Size: 0x4, Offset: FC, Data: 0x00CD1020
Size: 0x7, Offset: 00, Data: 0x00000000000000
Size: 0x7, Offset: 08, Data: 0x00000000000000
Size: 0x7, Offset: 10, Data: 0x00000000000000
Size: 0x7, Offset: 18, Data: 0x00000000000000
Size: 0x6, Offset: 20, Data: 0x000000000000
Size: 0x4, Offset: FC, Data: 0x00CF1020
Size: 0xF, Offset: 40, Data: 0x053564007700306001350535640077
Size: 0x1E, Offset: 50, Data: 0x000000000000000000000000000000000000000000000100000000000000
"""

tree = grammar.parse(idt_data)

iv = IDT8A34XXXVisitor()
output = iv.visit(tree)
print(output)
