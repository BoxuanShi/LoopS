#include <iostream>
#include <string>
#include "OnlineHelp.H"

// This global is needed by something
std::string packageDir = "packages";

int main()
{
  try
  {
    CoCoA::OnlineHelp::PrintAllExamplesWithoutOutput(std::cout);
  }
  catch (...)//(const CoCoA::ErrorInfo& err)
  {
//    ANNOUNCE(std::cerr, err);
    std::cerr << "---------------------------------------------------------------------------------" << std::endl;
    std::cerr << "Failed to open CoCoA manual XML file; it ought to be in CoCoAManual/CoCoAHelp.xml" << std::endl;
    std::cerr << "---------------------------------------------------------------------------------" << std::endl;
    exit(1);
  }
}
