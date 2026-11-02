add_library(
    subtitle
    subtitleentry.h
    mkvtools.cpp
    mkvtools.h
    reviewsession.cpp
    reviewsession.h
    subtitleeditor.cpp
    subtitleeditor.h
    subtitlelistmodel.cpp
    subtitlelistmodel.h
    subtitlelists.cpp
    subtitlelists.h
    subtitleparser.cpp
    subtitleparser.h
)
target_compile_features(subtitle PUBLIC cxx_std_20)
target_compile_options(subtitle PRIVATE ${MEMENTO_COMPILER_FLAGS})
target_include_directories(subtitle PRIVATE ${MEMENTO_INCLUDE_DIRS})
target_link_libraries(
    subtitle
    PRIVATE context
    PRIVATE mpvplayer
    PRIVATE Qt6::Concurrent
    PRIVATE utils
    PUBLIC Qt6::Core
)
