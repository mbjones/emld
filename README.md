
[![stability-experimental](https://img.shields.io/badge/stability-experimental-orange.svg)](https://github.com/joethorley/stability-badges#experimental) [![Travis-CI Build Status](https://travis-ci.org/cboettig/emld.svg?branch=master)](https://travis-ci.org/cboettig/emld) [![Coverage Status](https://img.shields.io/codecov/c/github/cboettig/emld/master.svg)](https://codecov.io/github/cboettig/emld?branch=master)

<!-- README.md is generated from README.Rmd. Please edit that file -->
emld
====

The goal of emld is to provide a way to work with EML metadata in the JSON-LD format. At it's heart, the package is simply a way to translate an EML XML document into JSON-LD and be able to reverse this so that any semantically equivalent JSON-LD file can be serialized into EML-schema valid XML.

In contrast to the existing [EML package](https://ropensci.github.io/EML), this package aims to a very light-weight implementation that seeks to provide both an intuitive data format and make maximum use of existing technology to work with that format.

This is very much **work in progress** The outline below illustrates things we can do or will be able to do with this package. The examples below are just a sketch of ideas so far, I hope to replace these with richer examples that will probably be developed more fully as vignettes.

Installation
------------

You can install emld from github with:

``` r
# install.packages("devtools")
devtools::install_github("cboettig/emld")
```

``` r
library(emld)
library(jsonlite)
library(magrittr)
```

Reading EML
-----------

The `EML` package can get particularly cumbersome when it comes to extracting and manipulating existing metadata in highly nested EML files. The `emld` approach can leverage a rich array of tools for reading, extracting, and manipulating existing EML files.

### Parse & serialize

We can parse a simple example and manipulate is as a familar list object (S3 object):

``` r
f <- system.file("extdata/example.xml", package="emld")
eml <- as_emld(f)
eml$dataset$title
#> [1] "Data from Cedar Creek LTER on productivity and species richness\n  for use in a workshop titled \"An Analysis of the Relationship between\n  Productivity and Diversity using Experimental Results from the Long-Term\n  Ecological Research Network\" held at NCEAS in September 1996."
```

``` r
eml$dataset$title <- "A new title"

as_xml(eml, "test.xml")
```

We can prove that writing the list back into XML still creates a valid EML file.

``` r
EML::eml_validate("test.xml")
#> [1] TRUE
#> attr(,"errors")
#> character(0)
unlink("test.xml")
```

### Query

We can query it with SPARQL, a rich, semantic way to extract data from one or many EML files.

``` r
library(rdflib)
```

FIXME replace with an example(s) that makes better use of semantic relationships.

``` r
f <- system.file("extdata/hf205.xml", package="emld")

as_emld(f) %>%
as_json("hf205.json")

sparql <- 
  'PREFIX eml: <http://ecoinformatics.org/>

  SELECT ?genus ?species ?northLat ?southLat ?eastLong ?westLong 

  WHERE { 
    ?y eml:taxonRankName "genus" .
    ?y eml:taxonRankValue ?genus .
    ?y eml:taxonomicClassification ?s .
    ?s eml:taxonRankName "species" .
    ?s eml:taxonRankValue ?species .
    ?x eml:northBoundingCoordinate ?northLat .
    ?x eml:southBoundingCoordinate ?southLat .
    ?x eml:eastBoundingCoordinate ?eastLong .
    ?x eml:westBoundingCoordinate ?westLong .
  }
'
  
rdf <- rdf_parse("hf205.json", "jsonld")
df <- rdf_query(rdf, sparql)
df
#>        genus  species northLat southLat eastLong westLong
#> 1 Sarracenia purpurea   +42.55   +42.42   -72.10   -72.29
```

We can query it with JQ, a [simple and powerful query language](https://stedolan.github.io/jq/manual/) that also gives us a lot of flexibility over the return structure of our results:

``` r
library(jqr)

as_emld(f) %>%
  as_json() %>% 
  as.character() %>%
  jq('.dataset.coverage.geographicCoverage.boundingCoordinates | 
       { northLat: .northBoundingCoordinate, 
         southLat: .southBoundingCoordinate }')
#> {
#>     "northLat": "+42.55",
#>     "southLat": "+42.42"
#> }
```

FIXME not sure how to avoid all the nulls when using recursive desent:

``` r
out <- 
  as_emld(f) %>%
  as_json() %>% 
  as.character() %>%
  jq('..|.boundingCoordinates? | 
       { northLat: .northBoundingCoordinate, 
         southLat: .southBoundingCoordinate }')
```

### Flatten and Compact.

We can flatten it, so we don't have to do quite so much subsetting. When we're done editing, we can compact it back into valid EML.

``` r
library(jsonld)
flat <- as_emld(f) %>%
  as_json() %>% 
  jsonld_flatten('{"@vocab": "http://ecoinformatics.org/"}') %>%
  fromJSON(simplifyVector = FALSE)
flat <- flat[["@graph"]]
```

FIXME this would be way more useful if nodes all had `@type` and were named by that type. Then we could do `flat$boundingCoordinates`. Currently flattened objects are unnamed and untyped, so this is less useful.

Writing EML
-----------

This section is even more experimental currently, and may not be a good direction for development. Nevertheless, it can illustrate some of the convenience (and risk) of a simple S3 class.

The `EML` package is arguably better suited to this task, where a collection of higher level `set_` functions can facilitate construction of EML. Still, working on the simple `list`-based classes can be convenient, particularly for developers. (For end-users, the simplicity of the `list` type also means that it is easy to define things that will create invalid EML, e.g. by mispelling a slot or providing a text value to a node-valued element). Nevertheless, one of of the main reasons the `EML` package is helpful in construction is simply the ability to a list of the possible slot names for any given object using the low-level approach of creating an object with the `new()` constructor and examining the slots (e.g. with tab completion).

Here we build on that basic insight by providing an elementary helper function, `template()`, which merely returns a list of the possible child elements (aka slots or properties) of the object. We can create EML from scratch using lists with help from the `template` function.

Let's create a minimal EML document

``` r
eml <- template("eml")
eml
#> access: {}
#> dataset: {}
#> citation: {}
#> software: {}
#> protocol: {}
#> additionalMetadata: {}
#> packageId: ~
```

Note that nodes which take data values are indicated by `~` while those where additional nodes are needed as arguments are indicated by `{}`. This gives us an idea of the possible elements (unfortunately it does not currently indicate which are required, optional, or mutually exclusive). We would also see these listed as tab-completion options if we type `eml$` using the usual list indexing mechanism.

Let's go ahead and get a dataset template as well.

``` r
dataset <- template("dataset")
```

Incidentally, `template` also knows about the EML schema types (always starting with a capital) which are used to type various objects.

``` r
contact <- template("ResponsibleParty")
contact
#> individualName: {}
#> organizationName: ~
#> positionName: ~
#> address: {}
#> phone: ~
#> electronicMailAddress: ~
#> onlineUrl: ~
#> userId: ~
```

Things stay a bit more tidy without recursion:

``` r
contact <- template("contact")
```

Let's start filling out some metadata!

``` r
contact$individualName$givenName <- list("Carl", "David")
contact$individualName$surName <- "Boettiger"
contact$organiziationName <- "UC Berkeley"
contact$electronicMailAddress <- "cboettig@ropensci.org"

contact <- purrr::compact(contact)
```

Note that repeated element types should be given as `list` types and not character vectors. This helps developers avoid unpredictable types. `purrr::compact()` is a convenient way to drop any fields we are not using once we're done.

``` r
dataset$title <- "Example Title"
dataset$creator <- contact
dataset$contact <- contact
eml$dataset <- dataset
```

(Still need to add a method to add JSON-LD context. Also need a method to compact out)

### Further ideas

Perhaps a flattened version could create an easier template to fill out that could then be coerced into valid EML. The original nested structure doesn't serve this purpose as well, since many 'keys' do not take values directly but get more nesting, e.g. you see `individualName` but you can't enter a name there. If you just saw the text-valued properties `givenName` and `surName` it might be a bit clearer.
