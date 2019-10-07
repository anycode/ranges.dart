part of ranges;

abstract class _Range<TYPE extends Comparable<TYPE>> with IterableMixin<TYPE> implements Comparable<_Range> {

  _Range(this._start, this._end, bool startInclusive, bool endInclusive, this._discrete) :
        this._startInclusive = _start == null ? false : startInclusive,
        this._endInclusive = _end == null ? false : endInclusive;

  _Range._(this._discrete);

  bool _startInclusive;
  TYPE _start;
  TYPE _end;
  bool _endInclusive;
  final bool _discrete;

  _Range<TYPE> newInstance();

  // if, else if blocks use following scenarios
  // 1. |-------------------| this
  //         |-----|                         that
  //
  // 2.    |-----|                         this
  //    |-------------------| that
  //
  // 3  |-------------|           this
  //                   |----------|    that
  //
  // 4            |-------------| this
  //    |--------|                       that
  //
  //  5 |-----|    |-----|         this that, that this


  List<_Range<TYPE>> union(_Range<TYPE> that) {
    final List<_Range<TYPE>> result = [];
    if (isSupersetOf(that)) {
      result.add(this);
    } else if (isSubsetOf(that)) {
      result.add(that);
    } else if (_esOverlap(that) || _esAdjacent(that)) {
      result.add(newInstance()
        .._startInclusive = _startInclusive
        .._start = _start
        .._end = that._end
        .._endInclusive = that._endInclusive);
    } else if (_seOverlap(that) || _seAdjacent(that)) {
      result.add(newInstance()
        .._startInclusive = that._startInclusive
        .._start = that._start
        .._end = _end
        .._endInclusive = _endInclusive);
    } else {
      result
        ..add(this)
        ..add(that);
    }
    return result;
  }

  List<_Range<TYPE>> except(_Range<TYPE> that) {
    final List<_Range<TYPE>> result = [];
    //if (this.start < that.start && this.end > that.end) {
    if (isSupersetOf(that)) {
      result
      ..add(newInstance()
          .._startInclusive = _startInclusive
          .._start = _start
          .._end = that._start
          .._endInclusive = ! that._startInclusive)
        ..add(newInstance()
          .._startInclusive = ! that._endInclusive
          .._start = that._end
          .._end = _end
          .._endInclusive = _endInclusive);
    } else if(isSubsetOf(that)) {
      // empty
    } else if (_esOverlap(that) || _esAdjacent(that)) {
      result.add(newInstance()
        .._startInclusive = _startInclusive
        .._start = _start
        .._end = that._start
        .._endInclusive = ! that._startInclusive);
    } else if (_seOverlap(that) || _seAdjacent(that)) {
      result.add(newInstance()
        .._startInclusive = ! that._endInclusive
        .._start = that._end
        .._end = _end
        .._endInclusive = _endInclusive);
    } else {
      result.add(this);
    }
    return result;
  }

  _Range<TYPE> intersect(_Range<TYPE> that) {
    _Range<TYPE> result = newInstance();
    //if (this.start <= that.star && this.end >= that.end) {
    if (isSupersetOf(that)) {
      result = that;
    } else if(isSubsetOf(that)) {
      result = this;
    } else if (_esOverlap(that) || _esAdjacent(that)) {
      result
        .._startInclusive = that._startInclusive
        .._start = that._start
        .._end = _end
        .._endInclusive = _endInclusive;
    } else if (_seOverlap(that) || _seAdjacent(that)) {
      result
        .._startInclusive = _startInclusive
        .._start = _start
        .._end = that._end
        .._endInclusive = that._endInclusive;
    } else {
      result = null;
    }
    return result;
  }

  /*
    A (this) is a subset of B (that) in these cases,
    * As = A.start, Ae = A.end, A[ = A.startInclusive, A( = ! A.startInclusive, A] = A.endInclusive, A) ! A.endInclusive
    1. not strict (is subset or equal)
        ( As > Bs || As = Bs && B[ ) && ( Ae < Be || Ae = Be && B] )
    2. strict (cannot equal)
       ( As > Bs || As = Bs && A( && B[ ) && (Ae < Be || Ae = Be && A) && B] )
   */
  bool isSubsetOf(_Range<TYPE> that, { bool strict = false }) => ! strict && _startGE(that) && _endLE(that) || strict && _startG(that) && _endL(that);

  bool isSupersetOf(_Range<TYPE> that, { bool strict = false }) => that.isSubsetOf(this, strict: strict);

  // A (this)  contains E (element) if
  // ( E > As || E == As && A[ ) && ( E < Ae || E = Ae && A] )
  bool contains(Object obj) {
    if(!(obj is TYPE)) return false;
    TYPE element = obj as TYPE;
    final int startCmp = _start?.compareTo(element) ?? -1; // -infinity is less than any value
    final int endCmp = _end?.compareTo(element) ?? 1; // infinity is greater than any value
    return (startCmp == -1 || startCmp == 0 && _startInclusive) && (endCmp == 1 || endCmp == 0 && _endInclusive);
  }

  bool isAdjacentTo(_Range<TYPE> that) {
    return _seAdjacent(that) || _esAdjacent(that);
  }

  bool overlaps(_Range<TYPE> that) {
    return _seOverlap(that) || _esOverlap(that);
  }

  List<_Range<TYPE>> operator +(_Range<TYPE> that) => union(that);

  List<_Range<TYPE>> operator -(_Range<TYPE> that) => except(that);

  _Range<TYPE> operator *(_Range<TYPE> that) => intersect(that);

  // private helper methods
  static int _cmp<TYPE extends Comparable<TYPE>>(TYPE a, TYPE b) => a != null && b != null ? a.compareTo(b)  : a == null ? -1 : b == null ? 1 : 0;

  // use _cmp(a,b,) if the other value is a range start too or is finite (not null) range end,
  // otherwise the other value is infinite (null) range end which is always greater
  int _startCmp(TYPE other, [bool otherIsStart = true]) => otherIsStart || other != null ? _cmp(_start, other) : -1;

  bool _startE(_Range<TYPE> that) => _startCmp(that._start) == 0 && _startInclusive == that._startInclusive;

  bool _startL(_Range<TYPE> that) => _startCmp(that._start) == -1 || _startCmp(that._start) == 0 && _startInclusive && ! that._startInclusive;

  bool _startLE(_Range<TYPE> that) => _startCmp(that._start) == -1 || _startCmp(that._start) == 0 && (_startInclusive || ! that._startInclusive);

  bool _startG(_Range<TYPE> that) => _startCmp(that._start) == 1 || _startCmp(that._start) == 0 && that._startInclusive && ! _startInclusive;

  bool _startGE(_Range<TYPE> that) => _startCmp(that._start) == 1 || _startCmp(that._start) == 0 && (that._startInclusive || ! _startInclusive);

  // use _cmp(a,b,) if the other value is a range end too or is finite (not null) range start,
  // otherwise the other value is -infinite (null) range start which is always less
  int _endCmp(TYPE other, [bool otherIsEnd = true]) => otherIsEnd || other != null ? _cmp(_end, other) : 1;

  bool _endE(_Range<TYPE> that) => _endCmp(that._end) == 0 && _endInclusive == that._endInclusive;

  bool _endL(_Range<TYPE> that) => _endCmp(that._end) == -1 || _endCmp(that._end) == 0 && that._endInclusive && ! _endInclusive;

  bool _endLE(_Range<TYPE> that) => _endCmp(that._end) == -1 || _endCmp(that._end) == 0 && (that._endInclusive || ! _endInclusive);

  bool _endG(_Range<TYPE> that) => _endCmp(that._end) == 1 || _endCmp(that._end) == 0 && _endInclusive && ! that._endInclusive;

  bool _endGE(_Range<TYPE> that) => _endCmp(that._end) == 1 || _endCmp(that._end) == 0 && (_endInclusive || ! that._endInclusive);

  // Adjacency
  // ranges A and B are adjacent if A.end and B.start are not null and
  // either A.end and B.start are equal and at least one is inclusive
  // A---][---B OK
  // A---](---B OK
  // A---)[---B OK
  // A---)(---B NOK
  // or A and B are discrete (int, date) and A.end and B.start are inclusive and are adjacent
  // A---]+1[---B OK
  // doesn't consider reverse adjacency
  static bool _adjacent<TYPE extends Comparable<TYPE>>(_Range<TYPE> a, _Range<TYPE> b) {
    return (a._end != null && b._start != null) &&
        ((a._endCmp(b._start, false) == 0 && (a._endInclusive || b._startInclusive))
            || (a._discrete && b._startCmp(a._next(a._end), false) == 0 && a._endInclusive && b._startInclusive));
  }

  bool _esAdjacent(_Range<TYPE> that) {
    return _adjacent(this, that);
  }

  bool _seAdjacent(_Range<TYPE> that) {
    return _adjacent(that, this);
  }

  // Overlap
  // ranges overlap if A.start <= B.start and A.end >= B.start
  // A [-------]
  // B      [-------]
  // doesn't consider reverse overlap
  static bool _overlap<TYPE extends Comparable<TYPE>>(_Range<TYPE> a, _Range<TYPE> b) {
    return a._startLE(b) && (a._end.compareTo(b._start) == 1 || a._end.compareTo(b._start) == 0 && a._endInclusive && b._startInclusive);
  }

  bool _esOverlap(_Range<TYPE> that) {
    return _overlap(this, that);
  }

  bool _seOverlap(_Range<TYPE> that) {
    return _overlap(that, this);
  }

  void _overrideInclusion(bool startInclusive, bool endInclusive) {
    // only discrete ranges can override inclusion
    if(! _discrete) return;
    if(startInclusive != null && startInclusive != _startInclusive) {
      // override start inclusion
      // change to next value for ( -> [  and change to prev value for [ -> (
      _start = startInclusive ? _next(_start) : _prev(_start);
      _startInclusive = startInclusive;
    }
    if(endInclusive != null && endInclusive != _endInclusive) {
      // override end inclusion
      // change to prev value for ) -> ]  and change to next value for ] -> )
      _end = endInclusive ? _prev(_end) : _next(_end);
      _endInclusive = endInclusive;
    }
  }

  TYPE _next(TYPE value);
  TYPE _prev(TYPE value);

  // return start/end of range with possible inclusion override. For non discrete ranges return unmodified values
  // see comments in void _overrideInclusion() for more
  TYPE start({bool inclusive}) => ! _discrete || _start == null || inclusive == null || _startInclusive == inclusive ? _start : inclusive ? _next(_start) : _prev(_start);
  TYPE end({bool inclusive}) => ! _discrete || _end == null || inclusive == null || _endInclusive == inclusive ? _end : inclusive ? _prev(_end) : _next(_end);
  bool get startInclusive => _startInclusive;
  bool get endInclusive => _endInclusive;

  @override
  int compareTo(_Range other) {
    int startCmp = _startCmp(other._start);
    return startCmp != 0 ? startCmp : _endCmp(other._end);
  }

  @override
  Iterator<TYPE> get iterator => _discrete && _start != null && _end != null
      ? _RangeIterator<TYPE>(this)
      : throw Exception('Cannot iterate over non-discrete and/or infinite range');

}

class _RangeIterator<TYPE extends Comparable<TYPE>> implements Iterator<TYPE> {
  final _Range<TYPE> _range;
  TYPE _element;

  _RangeIterator(this._range);

  @override
  TYPE get current => _element;

  @override
  bool moveNext() {
    if(_element == null) {
      _element = _range.start(inclusive: true);
    } else {
      _element = _range._next(_element);
    }
    return _element.compareTo(_range.end(inclusive: true)) <= 0;
  }

}
