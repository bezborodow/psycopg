"""
psycopg3_c.pq_cython.Escaping object implementation.
"""

# Copyright (C) 2020 The Psycopg Team


cdef class Escaping:
    def __init__(self, PGconn conn = None):
        self.conn = conn

    def escape_literal(self, data: "Buffer") -> memoryview:
        cdef char *out
        cdef bytes rv
        cdef char *ptr
        cdef Py_ssize_t length

        if self.conn is None:
            raise PQerror("escape_literal failed: no connection provided")
        if self.conn.pgconn_ptr is NULL:
            raise PQerror("the connection is closed")

        _buffer_as_string_and_size(data, &ptr, &length)

        out = impl.PQescapeLiteral(self.conn.pgconn_ptr, ptr, length)
        if out is NULL:
            raise PQerror(
                f"escape_literal failed: {error_message(self.conn)}"
            )

        return memoryview(PQBuffer._from_buffer(<unsigned char *>out, strlen(out)))

    def escape_identifier(self, data: "Buffer") -> memoryview:
        cdef char *out
        cdef char *ptr
        cdef Py_ssize_t length

        _buffer_as_string_and_size(data, &ptr, &length)

        if self.conn is None:
            raise PQerror("escape_identifier failed: no connection provided")
        if self.conn.pgconn_ptr is NULL:
            raise PQerror("the connection is closed")

        out = impl.PQescapeIdentifier(self.conn.pgconn_ptr, ptr, length)
        if out is NULL:
            raise PQerror(
                f"escape_identifier failed: {error_message(self.conn)}"
            )

        return memoryview(PQBuffer._from_buffer(<unsigned char *>out, strlen(out)))

    def escape_string(self, data: "Buffer") -> memoryview:
        cdef int error
        cdef size_t len_out
        cdef char *ptr
        cdef Py_ssize_t length
        cdef bytearray rv

        _buffer_as_string_and_size(data, &ptr, &length)

        rv = PyByteArray_FromStringAndSize("", 0)
        PyByteArray_Resize(rv, length * 2 + 1)

        if self.conn is not None:
            if self.conn.pgconn_ptr is NULL:
                raise PQerror("the connection is closed")

            len_out = impl.PQescapeStringConn(
                self.conn.pgconn_ptr, PyByteArray_AS_STRING(rv),
                ptr, length, &error
            )
            if error:
                raise PQerror(
                    f"escape_string failed: {error_message(self.conn)}"
                )

        else:
            len_out = impl.PQescapeString(PyByteArray_AS_STRING(rv), ptr, length)

        # shrink back or the length will be reported different
        PyByteArray_Resize(rv, len_out)
        return memoryview(rv)

    def escape_bytea(self, data: "Buffer") -> memoryview:
        cdef size_t len_out
        cdef unsigned char *out
        cdef char *ptr
        cdef Py_ssize_t length

        if self.conn is not None and self.conn.pgconn_ptr is NULL:
            raise PQerror("the connection is closed")

        _buffer_as_string_and_size(data, &ptr, &length)

        if self.conn is not None:
            out = impl.PQescapeByteaConn(
                self.conn.pgconn_ptr, <unsigned char *>ptr, length, &len_out)
        else:
            out = impl.PQescapeBytea(<unsigned char *>ptr, length, &len_out)

        if out is NULL:
            raise MemoryError(
                f"couldn't allocate for escape_bytea of {len(data)} bytes"
            )

        return memoryview(
            PQBuffer._from_buffer(out, len_out - 1)  # out includes final 0
        )

    def unescape_bytea(self, data: bytes) -> memoryview:
        # not needed, but let's keep it symmetric with the escaping:
        # if a connection is passed in, it must be valid.
        if self.conn is not None:
            if self.conn.pgconn_ptr is NULL:
                raise PQerror("the connection is closed")

        cdef size_t len_out
        cdef unsigned char *out = impl.PQunescapeBytea(data, &len_out)
        if out is NULL:
            raise MemoryError(
                f"couldn't allocate for unescape_bytea of {len(data)} bytes"
            )

        return memoryview(PQBuffer._from_buffer(out, len_out))
