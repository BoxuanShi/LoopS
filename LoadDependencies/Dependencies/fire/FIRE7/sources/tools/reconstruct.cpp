/** @file reconstruct.cpp
 *  @author Alexander Smirnov
 *
 *  This file is a part of the FIRE package
 *  It calls functions in recostruction.cpp with various methods
 */

#include "../handler.h"
#include "reconstruction.h"

/**
 * Entry Point for reconstruct.cpp.
 * @param argc number of arguments
 * @param argv array of arguments
 * @return 0 on success, but if steps_as_error_code is passed, then the number
 * of steps
 */
int main(int argc, char *argv[]) {
#ifdef WITH_DEBUG
    attach_handler();
#endif

#ifdef WITH_MPI
    int NET_SIZE, RANK;
    int provided = 0;
    int requested = MPI_THREAD_SINGLE;
    MPI_Init_thread(&argc, &argv, requested, &provided);
    if (provided < requested) {
        if (RANK == 0) {
            std::cout << "MPI requested thread safety " << requested << " was not obtained, only " << provided
                      << ", exiting." << std::endl;
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    MPI_Comm_rank(MPI_COMM_WORLD, &RANK);
    MPI_Comm_size(MPI_COMM_WORLD, &NET_SIZE);
    if (NET_SIZE < 1) {
        std::cout << "At least 2 processes are needed" << std::endl;
        MPI_Finalize();
        return EXIT_FAILURE;
    }
    auto result = reconstruct(argc, argv, RANK, NET_SIZE);
    MPI_Finalize();
#else
    auto result = reconstruct(argc, argv, std::nullopt, std::nullopt);
#endif

    return result;
}
