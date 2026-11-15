"""Compile the sheet's Excel formulas to Python and evaluate them, without a spreadsheet engine.

Supported (the subset the projections model uses): + - * / ^ and comparisons, unary +/-,
SUM, MAX, IF, IFERROR, AND, OR, ROUNDDOWN, MONTH, YEAR, POWER, CONCATENATE, cell refs, ranges,
and refs to another sheet. Anything else raises NotImplementedError when compiled.

Semantics that matter here:
- Empty cells read as 0 in arithmetic, and as blank (empty text) in CONCATENATE.
- IF and IFERROR evaluate only the branch they need (lazy branches).
- Errors (#DIV/0!, #VALUE!) propagate and are caught by IFERROR.
"""
import datetime as dt
import math
import re

from openpyxl.formula.tokenizer import Token, Tokenizer
from openpyxl.utils import column_index_from_string, get_column_letter

EXCEL_EPOCH = dt.date(1899, 12, 30)
_REF = re.compile(
    r"^(?:(?:'((?:[^']|'')+)'|([A-Za-z0-9_.]+))!)?"
    r"\$?([A-Z]{1,3})\$?(\d+)(?::\$?([A-Z]{1,3})\$?(\d+))?$"
)
_COMPILED = {}


class XLError(Exception):
    """An Excel error value (#DIV/0!, #VALUE!, ...). Raised when read, caught by IFERROR."""

    def __init__(self, code='#VALUE!'):
        super().__init__(code)
        self.code = code


def _serial_date(serial):
    return EXCEL_EPOCH + dt.timedelta(days=int(serial))


def _num(x):
    if x is None:
        return 0
    if isinstance(x, bool):
        return int(x)
    if isinstance(x, (int, float)):
        return x
    raise XLError('#VALUE!')


def _flat(args):
    for a in args:
        if isinstance(a, list):
            for x in a:
                yield x
        else:
            yield a


def f_SUM(*args):
    total = 0
    for x in _flat(args):
        if isinstance(x, (int, float)) and not isinstance(x, bool):
            total += x
    return total


def f_MAX(*args):
    nums = [x for x in _flat(args) if isinstance(x, (int, float)) and not isinstance(x, bool)]
    return max(nums) if nums else 0


def f_AND(*args):
    return all(bool(_num(x)) for x in _flat(args))


def f_OR(*args):
    return any(bool(_num(x)) for x in _flat(args))


def f_IF(cond, then=lambda: True, otherwise=lambda: False):
    return then() if bool(_num(cond)) else otherwise()


def f_IFERROR(value, fallback):
    try:
        v = value()
    except (XLError, ZeroDivisionError):
        return fallback()
    return v


def f_ROUNDDOWN(x, n=0):
    factor = 10 ** int(_num(n))
    return math.trunc(_num(x) * factor) / factor


def f_MONTH(serial):
    return _serial_date(_num(serial)).month


def f_YEAR(serial):
    return _serial_date(_num(serial)).year


def f_POWER(a, b):
    return _num(a) ** _num(b)


def _text(x):
    if x is None:
        return ''
    if isinstance(x, float) and x.is_integer():
        return str(int(x))
    return str(x)


def f_CONCATENATE(*args):
    return ''.join(_text(a) for a in args)


_FUNCS = {
    'SUM': 'f_SUM', 'MAX': 'f_MAX', 'AND': 'f_AND', 'OR': 'f_OR', 'IF': 'f_IF',
    'IFERROR': 'f_IFERROR', 'ROUNDDOWN': 'f_ROUNDDOWN', 'MONTH': 'f_MONTH',
    'YEAR': 'f_YEAR', 'POWER': 'f_POWER', 'POW': 'f_POWER', 'CONCATENATE': 'f_CONCATENATE',
}
_LAZY = {'IF', 'IFERROR'}
_INFIX = {'=': '==', '<>': '!=', '^': '**', '+': '+', '-': '-', '*': '*', '/': '/',
          '<': '<', '>': '>', '<=': '<=', '>=': '>='}


def _parse_ref(text, current_sheet):
    m = _REF.match(text)
    if not m:
        raise NotImplementedError(f'reference not supported: {text}')
    sheet = (m.group(1) or '').replace("''", "'") or m.group(2) or current_sheet
    c1, r1, c2, r2 = m.group(3), int(m.group(4)), m.group(5), m.group(6)
    return sheet, c1, r1, c2, (int(r2) if r2 else None)


def translate(formula, current_sheet):
    """Translate one Excel formula (starting with '=') to a Python expression string."""
    stack = []
    out = []
    in_concat = False
    for tok in Tokenizer(formula).items:
        if tok.type == Token.WSPACE:
            continue
        if tok.type == Token.FUNC and tok.subtype == Token.OPEN:
            name = tok.value[:-1].upper()
            if name not in _FUNCS:
                raise NotImplementedError(f'function not supported: {name}')
            if name == 'IFERROR':
                out.append(f'{_FUNCS[name]}(lambda: ')
            else:
                out.append(f'{_FUNCS[name]}(')
            stack.append(name)
            in_concat = in_concat or name == 'CONCATENATE'
        elif tok.type == Token.FUNC and tok.subtype == Token.CLOSE:
            name = stack.pop()
            out.append(')')
            in_concat = any(s == 'CONCATENATE' for s in stack)
        elif tok.type == Token.PAREN and tok.subtype == Token.OPEN:
            stack.append('(')
            out.append('(')
        elif tok.type == Token.PAREN and tok.subtype == Token.CLOSE:
            stack.pop()
            out.append(')')
        elif tok.type == Token.SEP and tok.subtype == Token.ARG:
            if stack and stack[-1] in _LAZY:
                out.append(', lambda: ')
            else:
                out.append(', ')
        elif tok.type == Token.OPERAND and tok.subtype == Token.RANGE:
            sheet, c1, r1, c2, r2 = _parse_ref(tok.value, current_sheet)
            if r2 is None:
                helper = 'RAW' if in_concat else 'R'
                out.append(f'{helper}({sheet!r}, {c1!r}, {r1})')
            else:
                out.append(f'RG({sheet!r}, {c1!r}, {r1}, {c2!r}, {r2})')
        elif tok.type == Token.OPERAND and tok.subtype == Token.NUMBER:
            out.append(tok.value)
        elif tok.type == Token.OPERAND and tok.subtype == Token.TEXT:
            out.append(repr(tok.value[1:-1].replace('""', '"')))
        elif tok.type == Token.OPERAND and tok.subtype == Token.LOGICAL:
            out.append('True' if tok.value.upper() == 'TRUE' else 'False')
        elif tok.type == Token.OP_PRE:
            out.append(tok.value)
        elif tok.type == Token.OP_IN:
            if tok.value not in _INFIX:
                raise NotImplementedError(f'operator not supported: {tok.value}')
            out.append(' ' + _INFIX[tok.value] + ' ')
        else:
            raise NotImplementedError(f'token not supported: {tok.type} {tok.subtype} {tok.value}')
    return ''.join(out)


def compile_formula(sheet, formula):
    key = (sheet, formula)
    code = _COMPILED.get(key)
    if code is None:
        code = compile(translate(formula, sheet), f'{sheet}!{formula}', 'eval')
        _COMPILED[key] = code
    return code


def _col2n(c):
    return column_index_from_string(c)


def normalise_cell(raw):
    """Turn a raw value read from a sheet into what Book should store.

    Numeric text becomes a float, empty becomes None, formula text and other values are kept.
    """
    if raw is None or raw == '':
        return None
    if isinstance(raw, str) and not raw.startswith('='):
        try:
            return float(raw)
        except ValueError:
            return raw
    if isinstance(raw, int) and not isinstance(raw, bool):
        return float(raw)
    return raw


class Book:
    """Cell values for one scenario. Cells are read lazily and memoised.

    cells: {sheet_name: {(column_letter, row): raw}} where raw is a constant or a formula string.
    """

    def __init__(self, cells):
        self.cells = cells
        self.cache = {}
        self.env = {
            'R': self._scalar, 'RAW': self._raw, 'RG': self._range,
            'f_SUM': f_SUM, 'f_MAX': f_MAX, 'f_AND': f_AND, 'f_OR': f_OR, 'f_IF': f_IF,
            'f_IFERROR': f_IFERROR, 'f_ROUNDDOWN': f_ROUNDDOWN, 'f_MONTH': f_MONTH,
            'f_YEAR': f_YEAR, 'f_POWER': f_POWER, 'f_CONCATENATE': f_CONCATENATE,
        }

    def _cell(self, sheet, col, row):
        key = (sheet, col, row)
        if key in self.cache:
            return self.cache[key]
        raw = self.cells.get(sheet, {}).get((col, row))
        if isinstance(raw, str) and raw.startswith('='):
            self.cache[key] = XLError('#CIRCULAR!')           # cycle guard
            try:
                val = eval(compile_formula(sheet, raw), self.env)
            except XLError as e:
                val = e
            except ZeroDivisionError:
                val = XLError('#DIV/0!')
            except (TypeError, ValueError, OverflowError):
                val = XLError('#VALUE!')
            if isinstance(val, int) and not isinstance(val, bool):
                val = float(val)
        else:
            val = float(raw) if isinstance(raw, int) and not isinstance(raw, bool) else raw
        self.cache[key] = val
        return val

    def _raw(self, sheet, col, row):
        v = self._cell(sheet, col, row)
        if isinstance(v, XLError):
            raise v
        return v

    def _scalar(self, sheet, col, row):
        v = self._raw(sheet, col, row)
        return 0 if v is None else v

    def _range(self, sheet, c1, r1, c2, r2):
        out = []
        for c in range(_col2n(c1), _col2n(c2) + 1):
            letter = get_column_letter(c)
            for r in range(r1, r2 + 1):
                out.append(self._raw(sheet, letter, r))
        return out

    def value(self, sheet, col, row):
        """Public accessor: returns the value, or the XLError instance if the cell is an error."""
        return self._cell(sheet, col, row)
