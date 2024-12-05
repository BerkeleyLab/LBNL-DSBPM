from parsimonious.grammar import Grammar
from parsimonious.nodes import NodeVisitor

from argparse import ArgumentParser

grammar = Grammar(
    r"""
    expr        = (reginstr / emptyline / commentline)*
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
    ws          = ~r"\s"
    commentline = startcomment+ comment endcomment
    startcomment = "#"
    comment     = commentchar*
    commentchar = ~r"[0-9A-Z- ,():/.]"i
    endcomment  = ws
    newline     = ~r"\n"
    endofstr    = ~r"$"
    emptyline   = ws+
    """
)


class IDT8A34XXXVisitor(NodeVisitor):
    def visit_expr(self, node, visited_children):
        """ Returns the overall output """

        output = []

        for child in visited_children:
            if (child and child[0]) is not None:
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


def getargs():
    from argparse import ArgumentParser

    parser = ArgumentParser()
    parser.add_argument("-f", "--file", metavar="FILE", required=True,
                        help="IDT register file")
    args = parser.parse_args()

    return args


def main():
    args = getargs()

    with open(args.file, "r") as f:
        tree = grammar.parse(f.read())

        iv = IDT8A34XXXVisitor()
        output = iv.visit(tree)
        print(output)


if __name__ == "__main__":
    main()
