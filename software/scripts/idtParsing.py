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

        reg_list = []

        for child in visited_children:
            if (child and child[0]) is not None:
                reg_list.append(child[0])

        for reg in reg_list:
            # offset will be part of data, so size = size +1
            reg_size = str(int(reg['Size'], 16) + 1)
            reg_offset = reg['Offset']

            reg_data_str = f"{reg['Data']}".removeprefix("0x")
            # Split hex number into hex bytes
            n = 2 # byte
            reg_data_split = [reg_data_str[i : i + n] for i in range(0, len(reg_data_str), n)]
            reg_data = [f"0x{d.ljust(2, '0')}" for d in reg_data_split]
            # reverse the list because we write LSB first
            reg_data.reverse()
            # add device I2C address to the data buffer
            reg_data.insert(0, reg_offset)

            reg_data_str = ", ".join(reg_data)

            regline = reg_size + ", {" + reg_data_str + "}"

            print("{" + regline + "},")

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
        return key.text, "0x" + value.text

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


if __name__ == "__main__":
    main()
