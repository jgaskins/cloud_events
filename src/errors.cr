module CloudEvents
  class Error < Exception
  end
  class UnsupportedFormatError < Error
  end
  class FormatSyntaxError < Error
  end
  class SpecVersionError < Error
  end
  class NotCloudEventError < Error
  end
end
