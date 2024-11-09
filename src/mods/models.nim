import std/times

type
  CustomFileInfo* = object
    path*: string
    lastModTime*: Time
