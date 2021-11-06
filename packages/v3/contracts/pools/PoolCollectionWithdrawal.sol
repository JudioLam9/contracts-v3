// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.9;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import { PPM_RESOLUTION } from "../utility/Constants.sol";
import { MathEx } from "../utility/MathEx.sol";

library PoolCollectionWithdrawal {
    using SafeCast for uint256;
    using SafeMath for uint256;

    uint256 private constant M = PPM_RESOLUTION;

    struct Output {
        int256 p;
        int256 q;
        int256 r;
        uint256 s;
        uint256 t;
        uint256 u;
    }

    struct Uint512 {
        uint256 hi;
        uint256 lo;
    }

    function formula(
        uint256 a, // <= 2**128-1
        uint256 b, // <= 2**128-1
        uint256 c, // <= 2**128-1
        uint256 e, // <= 2**128-1
        uint256 w, // <= 2**128-1
        uint256 m, // <= M == 1000000
        uint256 n, // <= M == 1000000
        uint256 x  // <= e <= 2**128-1
    ) internal pure returns (Output memory output) { unchecked {
        assert(a <= type(uint128).max);
        assert(b <= type(uint128).max);
        assert(c <= type(uint128).max);
        assert(e <= type(uint128).max);
        assert(w <= type(uint128).max);
        assert(m <= M);
        assert(n <= M);
        assert(x <= e);

        uint256 y = x * (M - n) / M;

        if (e * (M - n) / M > b + c) {
            uint256 f = e * (M - n) / M - (b + c);
            uint256 g = e - (b + c);
            if (hlim(b, c, e, x) && hmaxDeficit(b, e, f, g, m, n, x)) {
                output = arbitrageDeficit(a, b, e, f, m, x, y);
            } else {
                output = defaultDeficit(a, b, c, e, g, y);
                if (w > 0) {
                    uint256 tb = MathEx.mulDivF(a * y, g, e);
                    uint256 wa = w * a;
                    if (tb > wa) {
                        output.t = (tb - wa) / b;
                        output.u = w;
                    } else {
                        output.t = 0;
                        output.u = y * g / a;
                    }
                }
            }
        } else {
            uint256 f = MathEx.subMax0(b + c, e);
            if (f > 0 && hlim(b, c, e, x) && hmaxSurplus(b, e, f, m, n, x)) {
                output = arbitrageSurplus(a, b, e, f, m, n, x, y);
            } else {
                output = defaultSurplus(a, b, c, y);
            }
        }
    }}

    /**
     * @dev returns `bx < c(e-x)`
     */
    function hlim(
        uint256 b, // <= 2**128-1
        uint256 c, // <= 2**128-1
        uint256 e, // <= 2**128-1
        uint256 x  // <= e <= 2**128-1
    ) private pure returns (bool) { unchecked {
        return b * x < c * (e - x);
    }}

    /**
     * @dev returns `be((e(1-n)-b-c)m+en) > (e(1-n)-b-c)x(e-b-c)(1-m)`
     */
    function hmaxDeficit(
        uint256 b, // <= 2**128-1
        uint256 e, // <= 2**128-1
        uint256 f, // == e(1-n)-b-c <= e <= 2**128-1
        uint256 g, // == e-b-c <= e <= 2**128-1
        uint256 m, // <= M == 1000000
        uint256 n, // <= M == 1000000
        uint256 x  // <= e <= 2**128-1
    ) private pure returns (bool) { unchecked {
        return gt512(
            mul512(b * e, f * m + e * n),
            mul512(f * x, g * (M - m))
        );
    }}

    /**
     * @dev returns `be((b+c-e)m+en) > (b+c-e)x(b+c-e+en)(1-m)`
     */
    function hmaxSurplus(
        uint256 b, // <= 2**128-1
        uint256 e, // <= 2**128-1
        uint256 f, // <= b+c-e <= 2**129-2
        uint256 m, // <= M == 1000000
        uint256 n, // <= M == 1000000
        uint256 x  // <= e <= 2**128-1
    ) private pure returns (bool) { unchecked {
        return gt512(
            mul512(b * e, (f * m + e * n) * M),
            mul512(f * x, (f * M + e * n) * (M - m))
        );
    }}

    /**
     * @dev returns:
     * `p = ax(e(1-n)-b-c)(1-m)/(be-x(e(1-n)-b-c)(1-m))`
     * `q = 0`
     * `r = -x(e(1-n)-b-c)/e`
     * `s = y`
     * `t = 0`
     */
    function arbitrageDeficit(
        uint256 a, // <= 2**128-1
        uint256 b, // <= 2**128-1
        uint256 e, // <= 2**128-1
        uint256 f, // == e(1-n)-b-c <= e <= 2**128-1
        uint256 m, // <= M == 1000000
        uint256 x, // <= e <= 2**128-1
        uint256 y  // == x(1-n) <= x <= e <= 2**128-1
    ) private pure returns (Output memory output) { unchecked {
        uint256 h = f * (M - m);
        uint256 k = b.mul(e * M).sub(MathEx.mulDivF(x, h, 1));
        output.p = MathEx.mulDivF(a * x, h, k).toInt256();
        output.q = 0;
        output.r = -MathEx.mulDivF(x, f, e).toInt256();
        output.s = y;
        output.t = 0;
    }}

    /**
     * @dev returns:
     * `p = -ax(b+c-e+en)/(be(1-m)+x(b+c-e+en)(1-m))`
     * `q = 0`
     * `r = x(b+c-e+en)/e`
     * `s = y`
     * `t = 0`
     */
    function arbitrageSurplus(
        uint256 a, // <= 2**128-1
        uint256 b, // <= 2**128-1
        uint256 e, // <= 2**128-1
        uint256 f, // <= b+c-e <= 2**129-2
        uint256 m, // <= M == 1000000
        uint256 n, // <= M == 1000000
        uint256 x, // <= e <= 2**128-1
        uint256 y  // == x(1-n) <= x <= e <= 2**128-1
    ) private pure returns (Output memory output) { unchecked {
        uint256 h = f * M + e * n;
        uint256 k = b.mul(e * (M - m)).add(MathEx.mulDivF(x, h * (M - m), M));
        output.p = -MathEx.mulDivF(a * x, h, k).toInt256();
        output.q = 0;
        output.r = MathEx.mulDivF(x, h, e * M).toInt256();
        output.s = y;
        output.t = 0;
    }}

    /**
     * @dev returns:
     * `p = -a(x(1-n)b-c(e-x(1-n)))/be` if `x(1-n)b > c(e-x(1-n))` else `p = 0`
     * `q = -a(x(1-n)b-c(e-x(1-n)))/be` if `x(1-n)b > c(e-x(1-n))` else `q = 0`
     * `r = -(x(1-n)b-c(e-x(1-n)))/e` if `x(1-n)b > c(e-x(1-n))` else `r = 0`
     * `s = x(1-n)(b+c)/e`
     * `t = ax(1-n)(e-b-c)/be`
     */
    function defaultDeficit(
        uint256 a, // <= 2**128-1
        uint256 b, // <= 2**128-1
        uint256 c, // <= 2**128-1
        uint256 e, // <= 2**128-1
        uint256 g, // == e-b-c <= e <= 2**128-1
        uint256 y  // == x(1-n) <= x <= e <= 2**128-1
    ) private pure returns (Output memory output) { unchecked {
        uint256 z = MathEx.subMax0(y * b, c * (e - y));
        output.p = -MathEx.mulDivF(a, z, b * e).toInt256();
        output.q = output.p;
        output.r = -(z / e).toInt256();
        output.s = MathEx.mulDivF(y, b + c, e);
        output.t = MathEx.mulDivF(a * y, g, b * e);
    }}

    /**
     * @dev returns:
     * `p = -a(x(1-n)-c)/b` if `x(1-n) > c` else `p = 0`
     * `q = -a(x(1-n)-c)/b` if `x(1-n) > c` else `q = 0`
     * `r = -(x(1-n)-c)` if `x(1-n) > c` else `r = 0`
     * `s = x(1-n)`
     * `t = 0`
     */
    function defaultSurplus(
        uint256 a, // <= 2**128-1
        uint256 b, // <= 2**128-1
        uint256 c, // <= 2**128-1
        uint256 y  // == x(1-n) <= x <= e <= 2**128-1
    ) private pure returns (Output memory output) { unchecked {
        uint256 z = MathEx.subMax0(y, c);
        output.p = -MathEx.mulDivF(a, z, b).toInt256();
        output.q = output.p;
        output.r = -z.toInt256();
        output.s = y;
        output.t = 0;
    }}

    /**
     * @dev returns the value of `x * y`
     */
    function mul512(uint256 x, uint256 y) private pure returns (Uint512 memory) { unchecked {
        uint256 p = mulmod(x, y, type(uint256).max);
        uint256 q = x * y;
        uint256 r = p < q ? 1 : 0;
        return Uint512({ hi: p - q - r, lo: q });
    }}

    /**
     * @dev returns the value of `x > y`
     */
    function gt512(Uint512 memory x, Uint512 memory y) private pure returns (bool) { unchecked {
        return x.hi > y.hi || (x.hi == y.hi && x.lo > y.lo);
    }}
}
