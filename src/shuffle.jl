# Shuffle `values` in place, every arrangement being equally likely
# (Fisher-Yates). Position `i`, from the last down to the second, is swapped
# with a position drawn uniformly from `1:i`. The draw is Lemire's ("Fast
# Random Integer Generation in an Interval", 2019): a random 64-bit number
# times `i` is a 128-bit product whose high half is uniform on `0:i-1`, once
# the few products whose low half is under `2^64 mod i` are drawn again.
# That takes one random number per position in almost every case.
#
# The package has its own shuffle, and does not call `Random.shuffle!`, for
# speed, and so that the arrangement a stream gives is fixed by this
# function and not by the version of Julia.
function _shuffle!(rng, values)
    for i in length(values):-1:2
        bound = UInt64(i)
        product = widemul(rand(rng, UInt64), bound)
        low = product % UInt64
        if low < bound
            threshold = (-bound) % bound
            while low < threshold
                product = widemul(rand(rng, UInt64), bound)
                low = product % UInt64
            end
        end

        j = firstindex(values) + Int(product >> 64)
        k = firstindex(values) + i - 1
        (values[j], values[k]) = (values[k], values[j])
    end

    return values
end
